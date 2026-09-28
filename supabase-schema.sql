-- ============================================================================
--  Ficha de Tranpasse — esquema do Supabase
--  Rode este arquivo inteiro no SQL Editor do painel do Supabase, uma vez só.
--  Pode rodar de novo sem medo: tudo é idempotente.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
--  Tabela única: cada linha é uma ficha completa.
--  `dados`  = o estado do personagem (o mesmo objeto que a ficha já usava no navegador)
--  `sessao` = estado de combate (efeitos, rodada, log) — separado porque é volátil
-- ----------------------------------------------------------------------------
create table if not exists public.fichas (
  id            uuid primary key default gen_random_uuid(),
  dono          uuid not null references auth.users(id) on delete cascade,
  nome          text not null default 'Nova ficha',
  dados         jsonb not null default '{}'::jsonb,
  sessao        jsonb not null default '{}'::jsonb,
  publica       boolean not null default false,   -- true = quem tiver o link consegue ler
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

comment on column public.fichas.publica is
  'Quando true, qualquer pessoa com o link (que contém o id) pode LER a ficha. Escrita segue sendo só do dono.';

create index if not exists fichas_dono_idx    on public.fichas(dono);
create index if not exists fichas_publica_idx on public.fichas(publica) where publica;

-- ----------------------------------------------------------------------------
--  MESTRES
--  Quem estiver aqui enxerga e edita todas as fichas. Ninguém se cadastra
--  sozinho: a tabela não tem política de escrita, então só entra por este
--  SQL Editor — que só você acessa.
-- ----------------------------------------------------------------------------
create table if not exists public.mestres (
  usuario   uuid primary key references auth.users(id) on delete cascade,
  nome      text,
  criado_em timestamptz not null default now()
);

alter table public.mestres enable row level security;

drop policy if exists "logados veem quem é mestre" on public.mestres;
create policy "logados veem quem é mestre" on public.mestres
  for select using (auth.uid() is not null);
-- (sem policy de insert/update/delete de propósito: ninguém vira mestre pelo app)

-- security definer para a função conseguir ler a tabela sem depender da RLS de quem chama
create or replace function public.eh_mestre()
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.mestres m where m.usuario = auth.uid());
$$;

grant execute on function public.eh_mestre() to anon, authenticated;

-- ----------------------------------------------------------------------------
--  Segurança em nível de linha das fichas.
--  Sem isto, a chave pública do front daria acesso a tudo.
-- ----------------------------------------------------------------------------
alter table public.fichas enable row level security;

drop policy if exists "dono lê as próprias fichas"      on public.fichas;
drop policy if exists "qualquer um lê as públicas"      on public.fichas;
drop policy if exists "mestre lê todas"                 on public.fichas;
drop policy if exists "dono cria as próprias fichas"    on public.fichas;
drop policy if exists "dono atualiza as próprias"       on public.fichas;
drop policy if exists "mestre atualiza todas"           on public.fichas;
drop policy if exists "dono apaga as próprias"          on public.fichas;

create policy "dono lê as próprias fichas" on public.fichas
  for select using (auth.uid() = dono);

-- leitura pública: é o que faz o link compartilhado funcionar para quem não tem conta
create policy "qualquer um lê as públicas" on public.fichas
  for select using (publica = true);

-- o Mestre não depende de link nem de o jogador marcar como pública
create policy "mestre lê todas" on public.fichas
  for select using (public.eh_mestre());

create policy "dono cria as próprias fichas" on public.fichas
  for insert with check (auth.uid() = dono);

create policy "dono atualiza as próprias" on public.fichas
  for update using (auth.uid() = dono) with check (auth.uid() = dono);

-- ESCRITA DO MESTRE: pode corrigir qualquer ficha, mas não muda de dono
create policy "mestre atualiza todas" on public.fichas
  for update using (public.eh_mestre()) with check (public.eh_mestre() and dono = fichas.dono);

-- apagar continua sendo só do dono — nem o Mestre remove ficha de jogador
create policy "dono apaga as próprias" on public.fichas
  for delete using (auth.uid() = dono);

-- ----------------------------------------------------------------------------
--  atualizado_em sempre correto, sem depender do cliente mandar certo
-- ----------------------------------------------------------------------------
create or replace function public.toca_atualizado_em()
returns trigger language plpgsql as $$
begin
  new.atualizado_em = now();
  return new;
end $$;

drop trigger if exists fichas_atualizado_em on public.fichas;
create trigger fichas_atualizado_em
  before update on public.fichas
  for each row execute function public.toca_atualizado_em();

-- ----------------------------------------------------------------------------
--  Listagem enxuta: evita baixar o JSON inteiro de todas as fichas só para
--  montar o menu "Minhas fichas".
-- ----------------------------------------------------------------------------
create or replace view public.fichas_resumo as
  select id, dono, nome, publica, criado_em, atualizado_em,
         coalesce(dados->'basicos'->>'nome', '')           as personagem,
         coalesce(dados->'basicos'->>'classePrimaria', '') as classe,
         coalesce((dados->'basicos'->>'nivel')::int, 0)    as nivel
  from public.fichas;

-- a view herda a RLS da tabela de origem
alter view public.fichas_resumo set (security_invoker = on);

-- ============================================================================
--  COMO PROMOVER ALGUÉM A MESTRE
--  1. A pessoa precisa ter criado a conta na ficha pelo menos uma vez.
--  2. Painel → Authentication → Users → copie o e-mail dela.
--  3. Rode a linha abaixo trocando o e-mail:
--
--     insert into public.mestres (usuario, nome)
--     select id, 'Mestre' from auth.users where email = 'mestre@exemplo.com'
--     on conflict (usuario) do nothing;
--
--  Para tirar o poder de mestre:
--     delete from public.mestres m using auth.users u
--      where m.usuario = u.id and u.email = 'mestre@exemplo.com';
--
--  Conferir quem é mestre hoje:
--     select u.email, m.nome from public.mestres m join auth.users u on u.id = m.usuario;
-- ============================================================================
