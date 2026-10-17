# Nicholas Frechette's Blog

This repository holds the source of [nfrechette.github.io](https://nfrechette.github.io), a blog about animation compression, the [Animation Compression Library (ACL)](https://github.com/nfrechette/acl), math, and performance.

GitHub Pages builds the site with Jekyll from the `master` branch.

## Local preview

The site uses the `github-pages` gem, thus the local build uses the same versions as GitHub Pages. It needs Ruby 3.3 (with rbenv) and Bundler.

```bash
bundle install
./serve.sh                  # preview at http://localhost:4000
./serve.sh build            # one build into _site/
```

`serve.sh` also shows posts with a date in the future.

## Structure

- `_posts/`: the posts, one Markdown file for each post. `_posts/template.md` gives the minimal front matter.
- `_data/series.yml`: the posts of each series, in reading order.
- `_layouts/` and `_includes/`: the page templates.
- `topics/`: one page for each topic. The `tags:` of a post give its topics.
- `public/`: the images, videos, fonts, and style sheets.
- `acl_viewer/`: a prebuilt web app that shows glTF files compressed with ACL.

`CLAUDE.md` gives the full rules for posts, images, and videos.

## License

The theme is based on [Lanyon](https://github.com/poole/lanyon) by Mark Otto, released under the MIT license (see `LICENSE.md`). The fonts in `public/fonts/` are released under the SIL Open Font License. The posts are copyright Nicholas Frechette. All rights reserved.
