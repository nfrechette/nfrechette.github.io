# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Nicholas Frechette's personal blog (http://nfrechette.github.io), a Jekyll 3.9 site served by GitHub Pages from `master`. It uses the Lanyon theme (`README.md` is Lanyon's stock README, not project docs). Most posts are long-form technical articles about animation compression and the Animation Compression Library (ACL).

## Commands

```bash
./serve.sh                               # bundle exec jekyll serve --future (local preview at http://localhost:4000)
bundle exec jekyll build --future        # one-off build into _site/
```

`--future` is needed so posts dated after today still render. The `Gemfile` uses the `github-pages` gem, so local gem versions match what GitHub Pages builds with (Ruby 3.3.4, pinned locally via a gitignored `.ruby-version` for rbenv). The build needs a UTF-8 locale (`LANG=en_US.UTF-8`) or Sass fails on non-ASCII characters. There are no tests or linters; a clean `jekyll build` is the only check. `_site/` is build output and gitignored.

GitHub Pages renders any `.md` file as a page even without front matter (`jekyll-optional-front-matter`), including Liquid inside it. Repo-level docs like this file must be listed under `exclude:` in `_config.yml`; that list replaces Jekyll's default, so keep `Gemfile`/`Gemfile.lock` in it.

## Posts

- Posts live in `_posts/YYYY-MM-DD-slug.md`; the date and slug in the filename set the URL (`permalink: pretty` -> `/YYYY/MM/DD/slug/`). `_posts/template.md` is the minimal front matter starting point (`layout: post`, `title:`). Comments (Disqus) are on by default for posts via `_config.yml` defaults.
- Work-in-progress drafts are kept untracked in `_posts/` with placeholder dates such as `2024-99-99-...md`. These are not valid dates, so Jekyll will refuse to build while they're there; publishing means renaming the file to the real date.
- Link to other posts with `{% post_url YYYY-MM-DD-slug %}`, not hard-coded URLs.
- Images and other assets go in `public/`, usually under a per-topic subfolder (e.g. `public/acl/`, `public/matrix_multiplication/`), and are referenced with absolute paths: `![Alt](/public/acl/foo.jpg)`.
- Old URLs are kept alive with stub posts using `layout: redirected` plus `redirect_to:` (see `_layouts/redirected.html`); don't delete or rename published posts without leaving one of these.

## Site structure

- `_layouts/` (`default` -> `post`/`page`) and `_includes/` (`head`, `sidebar`, `comments`, `google_analytics`) are the theme. Pages with `layout: page` (e.g. `about.md`) automatically appear in the sidebar nav.
- `acl_viewer/` is a prebuilt, minified web app (ACL glTF viewer) checked in as static output; don't hand-edit it.

## Communication style

Write in ASD-STE100 (Simplified Technical English). This applies to what you say to the user, to
commit messages, to pull requests, and to comments and documents in the tree. Identifiers in code keep their names;
the specification controls prose only.

- **One word, one meaning, one part of speech.** Do not use a noun as a verb. Write "measure the
  function", not "benchmark the function".
- **Use the approved word when there is one.** Write "start", not "kick off"; "remove", not "strip
  out"; "let", not "permit". The technical nouns of this tree -- vector, quaternion, lane, mask,
  register, intrinsic -- are technical names and are approved by that rule.
- **Active voice, and name the agent.** Write "the function sets the [w] component", not "the [w]
  component is set". Use the passive voice only when the agent is not known or is not important.
- **Short sentences.** Maximum 20 words in an instruction, 25 in a description. Write one
  instruction in one sentence.
- **Do not use the -ing form as a noun or as an adjective.** Write "the code that loads", not
  "the loading code"; write "to clear the lane", not "clearing the lane".
- **Keep the articles and the helper words.** Write "the shuffle on the input vector", not "shuffle
  on input vector". Text that drops them is not faster to read.
- **Present tense, no figures of speech, and no words that carry an opinion.** A number is
  "5% lower", not "disappointing".
- **No Unicode characters** in comments, string literals, documents, commit messages, or pull
  requests. Use only ASCII. For example, use `<->` instead of `↔`, `--` instead of `—`, `->`
  instead of `→`. STE does not permit a Unicode dash either.

## Git

Commit messages are short and imperative. New articles use `Post <topic>` (e.g. `Post ACL 2.1 release`); other changes use plain descriptions like `Fix broken link`.
