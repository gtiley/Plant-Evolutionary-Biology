# Plant Evolutionary Biology

This is the GitHub repository used to manage materials for the class *Plant Evolutionary Biology*. You likely meant to navigate towards the rendered html via the website [here](https://gtiley.github.io/Plant-Evolutionary-Biology).

The website can be rendered locally with `jekyll` after cloning the repo. For example:
```
git clone -b gh-pages https://github.com/gtiley/Plant-Evolutionary-Biology.git
cd Plant-Evolutionary-Biology
bundle install
bundle exec jekyll serve --watch
```

For stability, this project pins `github-pages` in the Gemfile to a tested release. When you intentionally upgrade it, run `bundle update github-pages` and verify the site with a local build.

This might be helpful for replicating the structure when creating your own site. All teaching materials on the public github pages site are available for re-use for your own teaching and research purposes. Please, do not forget to remove names and contact information, including the various config files.

## Contributions

The class site is hosted from gh-pages and main is simply here to tell you this. Any contributions to the class site need to be made via a pull request. One should typically clone gh-pages-dev and push and make pull requests there for integration with gh-pages. If you want to clone the site for your own purposes, I would still clone or fork from gh-pages-dev.