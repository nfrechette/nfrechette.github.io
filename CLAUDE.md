# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Nicholas Frechette's personal blog (https://nfrechette.github.io), a Jekyll 3.10 site served by GitHub Pages from `master`. It uses the Lanyon theme (`README.md` is Lanyon's stock README, not project docs). Most posts are long-form technical articles about animation compression and the Animation Compression Library (ACL).

## Commands

```bash
./serve.sh                               # local preview at http://localhost:4000
./serve.sh build                         # one-off build into _site/
./serve.sh build -d /tmp/site            # extra arguments go to jekyll
```

`serve.sh` adds `--future`, so posts with a date after today also render. It puts the rbenv shims first on the `PATH` and sets `LANG=en_US.UTF-8`. Without the shims, a non-interactive shell uses the system Ruby 2.6, and the build fails. Without a UTF-8 locale, Sass fails on non-ASCII characters. The `Gemfile` uses the `github-pages` gem, so the local gem versions match the GitHub Pages build (Ruby 3.3.4, set in the gitignored `.ruby-version`). There are no tests or linters; a clean build is the only check. `_site/` is build output and gitignored.

GitHub Pages renders any `.md` file as a page even without front matter (`jekyll-optional-front-matter`), including Liquid inside it. Repo-level docs like this file must be listed under `exclude:` in `_config.yml`; that list replaces Jekyll's default, so keep `Gemfile`/`Gemfile.lock` in it.

## Posts

- Posts live in `_posts/YYYY-MM-DD-slug.md`; the date and slug in the filename set the URL (`permalink: pretty` -> `/YYYY/MM/DD/slug/`). `_posts/template.md` is the minimal front matter starting point (`layout: post`, `title:`). The site has no comment system.
- Work-in-progress drafts are kept untracked in `_posts/` with placeholder dates such as `2024-99-99-...md`. These are not valid dates, so Jekyll will refuse to build while they're there; publishing means renaming the file to the real date.
- Link to other posts with `{% post_url YYYY-MM-DD-slug %}`, not hard-coded URLs. This also applies to pages such as `about.md`. The build fails if the post does not exist.
- Give each post one or more topics with `tags:`, for example `tags: [animation-compression, releases]`. Use only the slugs of the files in `topics/`: `animation-compression`, `releases`, `math`, `performance`, `memory-allocation`, `gpgpu`, `windows`. Put the main topic first.
- Do not use `categories:`. With `permalink: pretty`, Jekyll puts the categories in the URL, and all old links break.
- To add a topic, add one file in `topics/` with `layout: topic`, `topic:` (the slug), `title:`, `order:`, and `description:`. The archive page, the post pages, and the feed read the topic name from that file.
- Start the sections of a post at `##`. The layout shows the post title as the only `h1`. Do not skip a level: a `###` heading must come after a `##` heading.
- The home page and the list pages show the excerpt of each post and a link to the full post. The excerpt is the first paragraph of the post. Posts must use LF line endings: in a CRLF file, Jekyll finds no paragraph end, and the excerpt is the full post.
- If a post starts with an image, a heading, or HTML, set `excerpt:` in the front matter. Jekyll does not convert this value from Markdown, so write it as HTML: `excerpt: "<p>...</p>"`. The SEO tag also uses the excerpt as the page description, unless the post sets `description:`.
- Give each post a `description:` of 160 characters or fewer, for search results and social cards. Without it, the SEO tag uses the full excerpt.
- If a post has an image, set `image:` to the best one and add `twitter:` with `card: summary_large_image`. Otherwise the post gets the site icon and a small card, from the defaults in `_config.yml`.
- `atom.xml` holds the full text of the newest 10 posts. It makes root-relative URLs (`/public/...`) absolute, so do not use protocol-relative URLs (`//host/...`) in posts.
- Images and other assets go in `public/`, usually under a per-topic subfolder (e.g. `public/acl/`, `public/matrix_multiplication/`), and are referenced with absolute paths: `![Alt](/public/acl/foo.jpg)`.
- Give each image its pixel size with a kramdown attribute list: `![Alt](/public/acl/foo.jpg){: width="1200" height="408"}`. The browser then reserves the space before the lazy image loads. `sips -g pixelWidth -g pixelHeight <file>` gives the size. To show an image smaller, set a smaller width and height with the same aspect ratio.
- Do not add animated GIFs. Convert each animation to MP4 and embed it with `<video width="..." height="..." autoplay loop muted playsinline poster="...">`. For a video that the user starts, use `controls preload="none" poster="..."`, so that the browser loads the file only on play. Give each video a JPEG poster of one frame. `ffmpeg` is not installed. A short Swift script with the macOS AVFoundation framework can do the conversion.
- Old URLs are kept alive with stub posts using `layout: redirected` plus `redirect_to:` (see `_layouts/redirected.html`); don't delete or rename published posts without leaving one of these. Give each stub `sitemap: false` and `hidden: true`. `hidden: true` removes the stub from the home page.
- The "Related Posts" list in `_layouts/post.html` shows the 3 posts that share the most topics with the post. If posts share the same number of topics, the post nearest in date comes first. Thus the `tags:` of a post also control this list.

## Site structure

- `_layouts/` (`default` -> `post`/`page`) and `_includes/` (`head`, `sidebar`, `post_list`, `post_topics`) are the theme. Pages with `layout: page` (e.g. `about.md`, `archive.html`) automatically appear in the sidebar nav. `archive.html` lists the topics and all posts by year, so it needs no change for a new post. `_layouts/topic.html` makes the topic pages at `/topics/<slug>/`. Both use `_includes/post_list.html`, and `_includes/post_topics.html` shows the topic links of a post.
- `_layouts/default.html` adds `loading="lazy"` to each `<img>` tag with a Liquid `replace`, because GitHub Pages does not permit custom plugins. `public/css/poole.css` limits images and videos to the width of the content column. In the same way, `default.html` puts each `<table>` in a `div.table-wrapper`. If a table is wider than the content column, the wrapper scrolls it. The theme sets `overflow-x: hidden` on the page, so without the wrapper the browser cuts off a wide table.
- A long line in a code block (`pre`) scrolls sideways and does not wrap. A tab in code is 4 spaces wide. A script in `default.html` gives a tab stop to each table wrapper and code block that scrolls, for keyboard users.
- The site title in the masthead is a `<p>`, not a heading. The title of the page is the first heading. The home page lists the post titles as `h2` headings, under an `h1` that only screen readers show (class `sr-only`). The sidebar checkbox has `aria-label="Menu"`, because its label is only the menu icon.
- The site loads no third-party resources: it has no analytics, and it serves its own fonts. `public/fonts/` holds the latin subset of PT Serif (400, 400 italic, 700) and PT Sans (400) as WOFF2, with the SIL Open Font License files. The `@font-face` rules are at the top of `public/css/lanyon.css`. `_includes/head.html` preloads the 2 regular fonts. To add a font style, add its WOFF2 file and an `@font-face` rule.
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
