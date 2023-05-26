[![Better Stack Badge](https://uptime.betterstack.com/status-badges/v1/monitor/os14.svg)](https://uptime.betterstack.com/?utm_source=status_badge)

# mhk-env_api
Application programming interface (API) to expose records (FERC/USACE docs, MarineCadastre spatial, etc) to PRIMRE search engine

Goal: Expose novel curated records to [PRIMRE Search Engine](https://openei.org/wiki/PRIMRE/Search?q=lubricant) using their [Metadata schema - PRIMRE/Guidelines | OpenEI](https://openei.org/wiki/PRIMRE/Guidelines#appendB)

## required folders

```bash
# reports written by user shiny into directory /share/user_reports
cd /share
sudo mkdir user_reports
sudo mkdir user_reports
sudo chmod -R g+w user_reports
sudo chgrp -R staff user_reports
groups shiny # confirm user shiny in group staff

# display of reports by nginx web server
ln -s /share/user_reports /share/github/www/report
```
