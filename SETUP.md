# Daily dashboard: setup guide

This version of the dashboard runs on its own website. Anyone can sign up with an email and password, with no Claude account, and the numbers sync between every phone and computer.

You need three free things: a **Supabase** account (it keeps the data and handles logins), a place to **host** the page (Netlify is the easiest), and the two files in this folder.

Plan about 30 minutes the first time. You do not need to write any code. You will copy and paste.

**Files in this folder**

| File | What it is |
|---|---|
| `index.html` | The dashboard itself. This is what you put on the website. |
| `supabase-setup.sql` | A script that prepares the database. You paste it into Supabase once. |
| `SETUP.md` | This guide. |

---

## Step 1. Make a Supabase project

1. Go to **supabase.com** and sign up (the free plan is enough).
2. Click **New project**.
3. Give it a name, for example `shop-dashboard`.
4. Make up a **database password** and save it somewhere safe. You will rarely need it.
5. Choose the **region closest to you** (for India, Mumbai or Singapore).
6. Click **Create new project** and wait a minute or two until it says it is ready.

## Step 2. Prepare the database

1. In your project, open **SQL Editor** (left menu) and click **New query**.
2. Open `supabase-setup.sql` in any text editor, select everything, and copy it.
3. Paste it into the SQL Editor and click **Run**.
4. You should see **Success**. If you see a red error, copy the message and send it to me.

To check it worked, paste this and Run. It should show 3 tables and 9 policies:

```sql
select (select count(*) from pg_tables where schemaname = 'public' and tablename in ('businesses','members','docs')) as tables,
       (select count(*) from pg_policies where schemaname = 'public') as policies;
```

## Step 3. Choose how people confirm their email

Open **Authentication** in the left menu, then find the **Email** sign in settings (it sits under Sign In / Providers, and the exact name can vary a little).

- **Easiest for a shop: turn "Confirm email" OFF.** People can sign up and use the dashboard straight away.
- If you leave it **ON**, every new person has to click a link in an email before they can log in. Supabase's built-in email service only sends a few emails per hour, so this gets stuck quickly unless you connect your own email sender later.

## Step 4. Connect the page to your project

1. In Supabase open **Project Settings**, then **API** (it may be called **API Keys**).
2. Copy the **Project URL**. It looks like `https://abcdefghijkl.supabase.co`.
3. Copy the **anon public** key. In newer versions it may be called the **publishable** key. It is a long text that starts with `eyJ` or `sb_publishable`.
4. Open `index.html` in a plain text editor (Notepad, TextEdit in plain text mode, or any code editor). Near the top, find these two lines:

   ```
   url: 'https://YOUR-PROJECT-ID.supabase.co',
   anonKey: 'YOUR-ANON-PUBLIC-KEY'
   ```

5. Replace what is between the quotes with your own Project URL and key. Save the file.

**Important.** Use only the **anon public** (publishable) key. Never paste the **service_role** or **secret** key anywhere in this file. The anon key is meant to be public. Your data stays private because of the rules from Step 2.

## Step 5. Put the page on the internet

The easiest way is Netlify Drop:

1. Make a new empty folder called `dashboard`. Put **only** your edited `index.html` in it.
2. Go to **app.netlify.com/drop** and sign in or sign up.
3. Drag the `dashboard` folder onto the page.
4. After a few seconds you get a web address like `https://something-random.netlify.app`. That is your dashboard. You can rename it in Netlify's site settings.

(Cloudflare Pages and GitHub Pages work too. Any host that serves a plain web page is fine.)

## Step 6. Tell Supabase your web address

This makes the password reset and email confirmation links come back to your dashboard.

1. In Supabase open **Authentication**, then **URL Configuration**.
2. Set **Site URL** to your dashboard address from Step 5.
3. Under **Redirect URLs**, add the same address and save.

## Step 7. Sign up as the owner

1. Open your dashboard address.
2. Tap **New here? Sign up**.
3. Choose **I own a business**, then enter your name, the business name, your email and a password.
4. You are in. Open the **Shop** tab to fill in your shop profile.

## Step 8. Add staff

1. On the **Shop** tab you will see a **business code** (for example `7F3A9C21`).
2. Send your staff the dashboard address and that code.
3. They tap **Sign up**, choose **I work for a business**, and enter their name, the code, their email and a password.
4. They see "Waiting for the owner to approve you". On your Overview you will see a banner. Open the **Shop** tab and tap **Make staff** (or **Make manager**).
5. Staff then log in on any phone and see only the screen for entering **today's** numbers. The database itself refuses to show them anything else, so older days stay private even if someone tries to look around.

If a code ever gets shared with the wrong person, tap **Make a new code**. The old one stops working.

---

## Moving your existing numbers

If you already used the dashboard inside Claude, open it there, go to **Report**, and tap **Download backup**. Log in to the new site as the owner, go to **Report**, tap **Restore from a backup file**, and choose that file. Your entries, spend categories and shop profile come across.

## Good to know

- **Time zone.** "Today" for staff is decided by the database in Indian time (Asia/Kolkata). If your shop is in another time zone, tell me and I will change one line.
- **One business per email.** Each email belongs to one business. Another business uses its own email and signs up as a new owner. Businesses cannot see each other.
- **Free plan pause.** Supabase may pause a free project that nobody has used for about a week. If the page shows an error after a long quiet spell, open your Supabase dashboard and press the restore button on the project. Your data is kept.
- **Backups.** Download a backup now and then from the **Report** tab. It is your safety copy outside Supabase.
- **Passwords.** Supabase stores passwords in scrambled form. "Forgot the password?" on the login screen emails a reset link.
- **Phones.** On a phone, open the address in the browser and use "Add to Home screen" to get an icon like an app.

## If something does not work

| What you see | What to do |
|---|---|
| "Not connected yet" | The two lines in Step 4 are still the placeholder text, or the quotes were damaged. Check them. |
| "Could not load the sign in" | The page could not reach the internet, or a filter blocked `cdn.jsdelivr.net`. Reload, or try another network. |
| "new row violates row-level security policy" | Step 2 did not finish. Run `supabase-setup.sql` again on a fresh project, or send me the error. |
| "Email not confirmed" | Turn off "Confirm email" (Step 3), or open the link in the email. |
| "Too many tries" or an email rate-limit message | Wait a few minutes, or turn off "Confirm email". |
| "That business code was not found" | Check the code in the owner's Shop tab. It has 8 letters and numbers. |
| A staff member cannot see old entries | That is intended. Staff only see today. |

## What I tested, and what I could not

I tested the whole page against a stand-in for Supabase: signing up, logging in, email confirmation, password reset, staff joining with a code and being approved, live sync between devices, downloads, and the rule that staff only receive today's entry. **I could not run `supabase-setup.sql` against a real Supabase project, and I could not test against a real Supabase server.** The first real run might need a small fix. If any step shows an error, copy the exact message and send it to me, and I will fix it.
