# teachspeech-site

Redesign of a shared website for three independent practitioners (two speech therapists, one psychologist). Static site built with [Eleventy](https://www.11ty.dev/), deployed on Netlify.

## Develop

```bash
nvm use          # Node 22
npm install
npm start        # http://localhost:8080
npm test         # prettier check + build + HTML validation (same as CI)
```

## Where content lives

- `src/_data/site.json` - name, phone, address, hours (shown in header, footer, contacts)
- `src/_data/specialists.json` - one entry per practitioner; each gets a profile page
- Anything highlighted yellow (`.ph`) is a missing-content placeholder. **Nothing is published without the practitioner's approval.**

## Workflow

- `main` is production (Netlify auto-deploys). Work on short-lived branches, open a PR, let CI pass, and use the Netlify deploy preview for review.
- Commit style: `feat:`, `fix:`, `content:`, `chore:`.

## Rules for this project

- No invented claims, credentials, prices or reviews. Real testimonials only with written consent.
- No photos of children.
- Keep old URLs alive (redirects in `netlify.toml`) once the real domain is connected.
