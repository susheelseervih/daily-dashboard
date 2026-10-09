# daily-dashboard

I built a separate version of the dashboard that runs on its own website. Anyone can sign up with an email and password, no Claude account is needed, and the numbers sync between every phone and computer. It isn’t live yet because it needs a free database account and a web address from you. I could not run it against a real Supabase account, so the first real run may need a small fix, and your published Claude link is unchanged.

What you get
The zip dashboard-self-hosted holds the same three files. The guide SETUP.md walks through it in 8 plain steps:

index.html: the dashboard, with every feature you already have.
supabase-setup.sql: a script you paste into Supabase once to prepare the database.
SETUP.md: the step-by-step guide, with a fix for each error you might see.

How it works for people

New owner: taps Sign up, chooses “I own a business”, and enters their name, business name, email and password.
Staff: the owner’s Shop tab shows a business code. Staff sign up with “I work for a business” and that code, then wait. The owner sees a banner and approves them as staff or manager.
Staff see only today: the database itself sends staff only today’s entry, so older days stay private even if someone tries to look around. This is stronger than before, because it no longer depends only on the screen.
Other features: each business is separate from every other. Forgot-password sends an email link. Reports, backups, the PDF statement and the WhatsApp summary all work.

What you need to do

Make a free Supabase project and paste in supabase-setup.sql.
Copy your project address and key into two lines of index.html.
Put index.html on a free host such as Netlify. You drag the folder, and it gives you a web address.
Open that address and sign up as the owner.

What I tested, and what I could not
I ran the whole page against a stand-in for Supabase, covering sign-up, login, email confirmation, password reset, staff joining and approval, live sync between devices, downloads, and the staff-only-today rule. The stand-in was written by me and enforces the access rules the way I understand them, so it is not proof that the real database script works. I could not run the script on a real database, and I could not test against a real Supabase server. If any step shows an error, copy the exact message and send it to me.

Costs and limits
The free Supabase plan may pause a project that sits unused for about a week, and its built-in email sends only a few messages an hour. SETUP.md explains both.

