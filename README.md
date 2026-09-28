# Ficha de Tranpasse

Ficha de personagem para o sistema Tranpasse. Uma página só, sem build e sem servidor:
o navegador fala direto com o Supabase.

```
public/index.html      a ficha inteira (HTML + CSS + JS num arquivo)
render.yaml            configuração do Render — cria o site sozinho
supabase-schema.sql    tabelas e regras de acesso do banco
```

---

# Publicar — passo a passo

## 1. Colocar no GitHub

No terminal, dentro desta pasta:

```bash
git init
git add .
git commit -m "Ficha de Tranpasse"
git branch -M main
```

Crie um repositório vazio em **github.com/new** — **sem** README, **sem** .gitignore,
**sem** licença (o repositório precisa estar vazio). Depois:

```bash
git remote add origin https://github.com/SEU-USUARIO/ficha-tranpasse.git
git push -u origin main
```

## 2. Publicar no Render

1. Entre em **render.com** e conecte sua conta do GitHub
2. **New → Static Site** ⚠️ *não escolha "Web Service"*
3. Selecione o repositório `ficha-tranpasse`
4. Preencha exatamente assim:

   | Campo | Valor |
   |---|---|
   | **Name** | `ficha-tranpasse` |
   | **Branch** | `main` |
   | **Root Directory** | *(deixe vazio)* |
   | **Build Command** | *(deixe vazio)* |
   | **Publish Directory** | `public` |

5. **Create Static Site**

Em menos de um minuto o endereço fica no ar, algo como
`https://ficha-tranpasse.onrender.com`.

> ### Se o build falhar
> Quase sempre é um destes três:
> - Foi criado **Web Service** em vez de **Static Site**. O Web Service procura uma
>   aplicação para rodar, não acha, e falha. Apague e crie de novo como Static Site.
> - O **Build Command** tem alguma coisa escrita. Tem que estar **vazio** — não há o que
>   compilar aqui.
> - O **Publish Directory** está errado. Tem que ser `public`, que é onde está o
>   `index.html`.
>
> Como este repositório traz o `render.yaml`, você também pode usar
> **New → Blueprint** e apontar para o repositório: o Render lê o arquivo e configura
> tudo sozinho, sem chance de errar campo.

## 3. Ligar o banco

O arquivo já vem apontado para um projeto Supabase. Se for usar outro, abra
`public/index.html` e troque as duas linhas do topo:

```js
const SUPABASE_URL = "https://SEU-PROJETO.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_...";
```

Use sempre a chave **publishable** (ou a `anon`). **Nunca** a `secret` nem a
`service_role`: essas ignoram todas as regras de acesso e não podem ficar no navegador.

Se for um projeto novo, rode antes o `supabase-schema.sql` no **SQL Editor** do painel.

## 4. Definir o Mestre

O mestre precisa poder editar todas as fichas. Isso só se ativa pelo banco — assim
ninguém se promove sozinho.

1. Peça para ele abrir o site e **criar a conta**
2. No Supabase: **SQL Editor → New query**, cole trocando o e-mail:

```sql
insert into public.mestres (usuario, nome)
select id, 'Mestre' from auth.users where email = 'mestre@exemplo.com'
on conflict (usuario) do nothing;
```

3. **Run**

---

# Como funciona para quem abre

Ao abrir o site, aparece a tela de entrada. **Não existe ficha antes do login** — nem
em branco, nem de exemplo. Quem cria a conta recebe automaticamente uma ficha vazia,
que é só dele.

| Quem | Pode |
|---|---|
| **Jogador** | criar, ver e editar apenas as próprias fichas |
| **Mestre** | ver e editar as fichas de todos; não apaga ficha de jogador |
| **Link compartilhado** | apenas leitura, e só se o dono ligar a opção |

## Trazendo uma ficha que já existe

Quem já tinha a ficha montada no navegador antes de subir para a nuvem:

1. Na versão antiga, **⬇ Exportar** e guarde o `.json`
2. No site novo, crie a conta (a ficha vazia nasce junto)
3. **⬆ Importar** e escolha o arquivo

---

# O que é salvo

| | Onde |
|---|---|
| Personagem (atributos, perícias, magias, itens…) | nuvem + navegador |
| Sessão (efeitos ativos, rodada, reações, log) | nuvem + navegador |
| Tema, zoom e tamanho de fonte | dentro da ficha, viajam junto |

O navegador grava na hora; a nuvem espera 1,5 s depois da última alteração. Sem
internet nada trava: continua salvando local, o indicador mostra
**offline — salvo aqui**, e sincroniza quando a conexão voltar.

---

# Atualizar depois

```bash
git add .
git commit -m "o que mudou"
git push
```

O Render publica sozinho a cada push.
