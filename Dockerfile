FROM upadrishta/raspi:2019-09-26

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y curl git libssl-dev cmake cpp\
    bash-completion \
    ca-certificates \
    gcc gfortran libreadline6-dev libx11-dev libxt-dev \
    libpng-dev libjpeg-dev libcairo2-dev xvfb \
    libbz2-dev libzstd-dev liblzma-dev \
    libcurl4-openssl-dev libgfortran5 \
    texinfo texlive texlive-fonts-extra \
    screen wget openjdk-8-jdk

# Enable systemd
ARG R_VERSION
ARG BUILD_DATE
ENV R_VERSION=${R_VERSION:-3.6.2} \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8
#    TERM=xterm 
ENV INITSYSTEM on

# install latest R
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen en_US.utf8 \
  && /usr/sbin/update-locale LANG=en_US.UTF-8 \
  && BUILDDEPS="curl \
    bash-completion \
    ca-certificates \
    gcc gfortran libreadline6-dev libx11-dev libxt-dev \
    libpng-dev libjpeg-dev libcairo2-dev xvfb \
    libbz2-dev libzstd-dev liblzma-dev \
    libcurl4-openssl-dev libgfortran5 \
    texinfo texlive texlive-fonts-extra \
    screen wget openjdk-8-jdk" \
  && apt-get install -y --no-install-recommends $BUILDDEPS \
  && cd tmp/ \
  ## Download source code
  && curl -O https://cran.r-project.org/src/base/R-3/R-${R_VERSION}.tar.gz \
  ## Extract source code
  && tar -xf R-${R_VERSION}.tar.gz \
  && cd R-${R_VERSION} \
  ## Set compiler flags
  && R_PAPERSIZE=letter \
    R_BATCHSAVE="--no-save --no-restore" \
    R_BROWSER=xdg-open \
    PAGER=/usr/bin/pager \
    PERL=/usr/bin/perl \
    R_UNZIPCMD=/usr/bin/unzip \
    R_ZIPCMD=/usr/bin/zip \
    R_PRINTCMD=/usr/bin/lpr \
    LIBnn=lib \
    AWK=/usr/bin/awk \
    CFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g" \
    CXXFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g" \
  ## Configure options
  ./configure --enable-R-shlib \
               --enable-memory-profiling \
               --with-readline \
               --with-blas \
               --with-tcltk \
               --disable-nls \
               --with-recommended-packages \
  ## Build and install
  && make \
  && make install \
  ## Add a default CRAN mirror
  && echo "options(repos = c(CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl')" >> /usr/local/lib/R/etc/Rprofile.site \
  ## Add a library directory (for user-installed packages)
  && mkdir -p /usr/local/lib/R/site-library \
  && chown root:staff /usr/local/lib/R/site-library \
  && chmod g+wx /usr/local/lib/R/site-library \
  ## Fix library path
  && sed -i '/^R_LIBS_USER=.*$/d' /usr/local/lib/R/etc/Renviron \
  && echo "R_LIBS_USER=\${R_LIBS_USER-'/usr/local/lib/R/site-library'}" >> /usr/local/lib/R/etc/Renviron \
  && echo "R_LIBS=\${R_LIBS-'/usr/local/lib/R/site-library:/usr/local/lib/R/library:/usr/lib/R/library'}" >> /usr/local/lib/R/etc/Renviron \
  ## install packages from date-locked MRAN snapshot of CRAN
  && [ -z "$BUILD_DATE" ] && BUILD_DATE=$(TZ="America/Los_Angeles" date -I) || true \
  && MRAN=https://mran.microsoft.com/snapshot/${BUILD_DATE} \
  && echo MRAN=$MRAN >> /etc/environment \
  && export MRAN=$MRAN \
  && echo "options(repos = c(CRAN='$MRAN'), download.file.method = 'libcurl')" >> /usr/local/lib/R/etc/Rprofile.site \
  ## Use littler installation scripts
  && Rscript -e "install.packages(c('littler', 'docopt'), repo = '$MRAN')" \
  && ln -s /usr/local/lib/R/site-library/littler/examples/install2.r /usr/local/bin/install2.r \
  && ln -s /usr/local/lib/R/site-library/littler/examples/installGithub.r /usr/local/bin/installGithub.r \
  && ln -s /usr/local/lib/R/site-library/littler/bin/r /usr/local/bin/r \
  ## Clean up from R source install
  && cd / \
  && rm -rf /tmp/* \
  ##&& apt-get remove --purge -y $BUILDDEPS \
  && apt-get autoremove -y \
  && apt-get autoclean -y 
  ##&& rm -rf /var/lib/apt/lists/*

## just a few R packages for finance stuff....
## if this fails do this at the beginning
##   R -e "install.packages('remotes', repos='http://cran.rstudio.com/', type='source')" && \
#    R -e "remotes::install_github('r-lib/later')" && \
#    R -e "install.packages('later', repos='http://cran.rstudio.com/', type='source')" && \

RUN R -e "install.packages('remotes', repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('later', repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('Rcpp', repos='http://cran.rstudio.com/', type='source')" && \
    R -e "install.packages('httpuv', repos='http://cran.rstudio.com/)" && \
    R -e "install.packages('fs', repos='http://cran.rstudio.com/')" && \ 
    R -e "install.packages('mime', repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('jsonlite', repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('digest', repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('htmltools', repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('xtable', repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('R6', repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('Cairo', repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('sourcetools', repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('shiny', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('shiny.semantic', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('semantic.dashboard', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('shinythemes', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('DT', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('quantmod', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('Quandl', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('lubridate', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('plyr', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('magrittr', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('tidyquant', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('RPostgreSQL', repos='https://cran.rstudio.com/')" && \
    R -e "install.packages('plotly', repos='https://cran.rstudio.com/')"; 

    # install shiny-server
RUN cd && \
    uname -a && \
    git clone https://github.com/rstudio/shiny-server.git && \
    cd shiny-server && \
    mkdir tmp && \
    cd tmp && \
    PATH=$PWD/../bin:$PATH && \
    #
    PYTHON=`which python` && \
    #
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DPYTHON="$PYTHON" ../ && \
    #
    make && \
    mkdir ../build && \
    # zap some stuff in external/node/install-node.sh
    sed -i 's/NODE_SHA256=.*/NODE_SHA256=bc7d4614a52782a65126fc1cc89c8490fc81eb317255b11e05b9e072e70f141d/' ../external/node/install-node.sh && \
    sed -i 's/linux-x64.tar.xz/linux-armv7l.tar.xz/' ../external/node/install-node.sh && \   
    sed -i 's#github.com/jcheng5/node-centos6/releases/download#nodejs.org/dist#' ../external/node/install-node.sh && \
    cat ../external/node/install-node.sh && \
    (cd .. && ./external/node/install-node.sh) && \
    (cd .. && ./bin/npm --python="${PYTHON}" install --no-optional) && \
    (cd .. && ./bin/npm --python="${PYTHON}" rebuild) && \
    sudo make install

# shiny-server post-install
RUN useradd -r -m shiny && usermod -aG sudo shiny && \
    ln -s /usr/local/shiny-server/bin/shiny-server /usr/bin/shiny-server && \
    sudo mkdir -p /var/log/shiny-server && \
    sudo mkdir -p /srv/shiny-server && \
    sudo mkdir -p /var/lib/shiny-server && \
    sudo chown shiny /var/log/shiny-server && \
    sudo mkdir -p /etc/shiny-server && \
    # configuration
    wget https://raw.githubusercontent.com/mk-mohan/raspirshiny/master/shiny-server.conf -O /etc/shiny-server/shiny-server.conf && \
    # example app
    wget https://raw.githubusercontent.com/mk-mohan/raspirshiny/master/hello/app.R -P /srv/shiny-server/hello
# 
EXPOSE 3838
CMD ["sudo shiny-server"]