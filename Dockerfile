FROM ubuntu:bionic

# Suppress debconf warnings
ENV DEBIAN_FRONTEND noninteractive

# Install dependencies
RUN echo 'deb http://us.archive.ubuntu.com/ubuntu bionic main multiverse' >> /etc/apt/sources.list && \
    apt-get update -y && \
    apt-get --no-install-recommends -y install \
    build-essential \
    autoconf \
    autotools-dev \
    automake \
    autogen \
    libtool \
    pkg-config \
    csh \
    gcc \
    gfortran \
    wget \
    git \
    libcfitsio-dev \
    pgplot5 \
    swig3.0 \
    python3 \
    python3-dev \
    python3-pip \
    libfftw3-3 \
    libfftw3-bin \
    libfftw3-dev \
    libfftw3-single3 \
    libx11-dev \
    libpng-dev \
    libpnglite-dev \
    libxml2 \
    libxml2-dev \
    libltdl-dev \
    gsl-bin \
    libgsl-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get -y clean

RUN ln -s /usr/bin/python3 /usr/bin/python && \
ln -s  /usr/bin/swig3.0  /usr/bin/swig



# Install python2 packages
RUN pip3 install pip -U && \
    pip3 install setuptools -U && \
    pip3 install numpy -U && \
    pip3 install scipy -U && \
    pip3 install watchdog && \
    pip3 install matplotlib -U && \
    pip3 install bilby -U && \
    pip3 install -U setuptools setuptools_scm pep517 && \
    pip3 install -U emcee && \
    pip3 install jupyterlab -U && \
    pip install git+https://github.com/FRBs/sigpyproc3
    


# PGPLOT
ENV PGPLOT_DIR /usr/lib/pgplot5
ENV PGPLOT_FONT /usr/lib/pgplot5/grfont.dat
ENV PGPLOT_INCLUDES /usr/include
ENV PGPLOT_BACKGROUND white
ENV PGPLOT_FOREGROUND black
ENV PGPLOT_DEV /xs

ENV PSRHOME /software/
WORKDIR $PSRHOME 

# Pull all repos
RUN wget http://www.atnf.csiro.au/people/pulsar/psrcat/downloads/psrcat_pkg.tar.gz && \
    tar -xvf psrcat_pkg.tar.gz -C $PSRHOME && \
    git clone https://bitbucket.org/psrsoft/tempo2.git && \
    git clone git://git.code.sf.net/p/psrchive/code psrchive && \
    git clone https://github.com/SixByNine/psrxml.git && \
    git clone https://github.com/straten/epsic.git && \
    git clone  git://git.code.sf.net/p/tempo/tempo && \
    git clone git://git.code.sf.net/p/dspsr/code dspsr

#PSRCAT
ENV PSRCAT_FILE $PSRHOME/psrcat_tar/psrcat.db
ENV PATH $PATH:$PSRHOME/psrcat_tar
WORKDIR $PSRHOME/psrcat_tar
RUN /bin/bash makeit && \
    rm -f ../psrcat_pkg.tar.gz

# PSRXML
ENV PSRXML $PSRHOME/psrxml
ENV PATH $PATH:$PSRXML/install/bin
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$PSRXML/install/lib
ENV C_INCLUDE_PATH $C_INCLUDE_PATH:$PSRXML/install/include
WORKDIR $PSRXML
RUN autoreconf --install --warnings=none
RUN ./configure --prefix=$PSRXML/install && \
    make -j && \
    make install && \
    rm -rf .git

# tempo
ENV TEMPO=$PSRHOME/tempo
ENV PATH=$PATH:$PSRHOME/tempo/bin
WORKDIR $PSRHOME/tempo
RUN ./prepare && \
    ./configure --prefix=$PSRHOME/tempo && \
    make && \
    make install    

# tempo2
ENV TEMPO2 $PSRHOME/tempo2/T2runtime
ENV PATH $PATH:$PSRHOME/tempo2/T2runtime/bin
ENV C_INCLUDE_PATH $C_INCLUDE_PATH:$PSRHOME/tempo2/T2runtime/include
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$PSRHOME/tempo2/T2runtime/lib
WORKDIR $PSRHOME/tempo2
RUN sync && perl -pi -e 's/chmod \+x/#chmod +x/' bootstrap # Get rid of: returned a non-zero code: 126.
RUN ./bootstrap && \
    ./configure --x-libraries=/usr/lib/x86_64-linux-gnu --enable-shared --enable-static --with-pic F77=gfortran && \
    make -j $(nproc) && \
    make install && \
    make plugins-install && \
    rm -rf .git

#COPY gbt2gps.clk $TEMPO2/clock/
#COPY mk2utc.clk $TEMPO2/clock/
    

# PSRCHIVE
ENV PSRCHIVE $PSRHOME/psrchive
ENV PATH $PATH:$PSRCHIVE/install/bin
ENV C_INCLUDE_PATH $C_INCLUDE_PATH:$PSRCHIVE/install/include
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$PSRCHIVE/install/lib
ENV PYTHONPATH $PSRCHIVE/install/lib/python2.7/site-packages
WORKDIR $PSRCHIVE
RUN git checkout 844461775b4b6f4b4e786d323ae82224b63c0e85 && ./bootstrap && \
    ./configure --prefix=$PSRCHIVE/install --x-libraries=/usr/lib/x86_64-linux-gnu --with-psrxml-dir=$PSRXML/install --enable-shared --enable-static F77=gfortran LDFLAGS="-L"$PSRXML"/install/lib" LIBS="-lpsrxml -lxml2" && \
    make -j $(nproc) && \
    make && \
    make install

# DSPSR
ENV DSPSR $PSRHOME/dspsr
ENV PATH $PATH:$DSPSR/install/bin
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$DSPSR/install/lib
ENV C_INCLUDE_PATH $C_INCLUDE_PATH:$DSPSR/install/include
WORKDIR $DSPSR
RUN ./bootstrap && \
    echo "apsr asp bcpm bpsr caspsr cpsr cpsr2 dummy fits kat lbadr lbadr64  lump lwa puma2 sigproc ska1 " > backends.list && \
    ./configure --prefix=$DSPSR/install && \
    make -j $(nproc) && \
    make && \
    make install


LABEL Vivek Venkatraman Krishnan "vkrishnan@mpifr-bonn.mpg.de"
ENV PYTHONPATH $PYTHONPATH:$PSRCHIVE/install/lib/python3.6/site-packages/

WORKDIR $PSRHOME

RUN echo "" >> .bashrc && \
    echo "if [ -e \$PSRHOME/source_this.bash ]; then" >> .bashrc && \
    echo "   source \$PSRHOME/source_this.bash" >> .bashrc && \
    echo "fi" >> .bashrc && \
    echo "" >> .bashrc && \
    echo "alias rm='rm -i'" >> source_this.bash && \
    echo "alias mv='mv -i'" >> source_this.bash && \
    echo "export OSTYPE=linux" >> source_this.bash && \
    echo "" >> source_this.bash && \
    echo "# Up arrow search" >> source_this.bash && \
    echo "export HISTFILE=\$HOME/.bash_eternal_history" >> source_this.bash && \
    echo "export HISTFILESIZE=" >> source_this.bash && \
    echo "export HISTSIZE=" >> source_this.bash && \
    echo "export HISTCONTROL=ignoreboth" >> source_this.bash && \
    echo "export HISTIGNORE=\"l:ll:lt:ls:bg:fg:mc:history::ls -lah:..:ls -l;ls -lh;lt;la\"" >> source_this.bash && \
    echo "export HISTTIMEFORMAT=\"%F %T \"" >> source_this.bash && \
    echo "export PROMPT_COMMAND=\"history -a\"" >> source_this.bash && \
    echo "bind '\"\e[A\":history-search-backward'" >> source_this.bash && \
    echo "bind '\"\e[B\":history-search-forward'" >> source_this.bash && \
    echo "" >> source_this.bash && \
    echo "# tempo" >> source_this.bash && \
    echo "export TEMPO=\$PSRHOME/tempo" >> source_this.bash && \
    echo "export PATH=\$PATH:\$TEMPO/bin" >> source_this.bash && \
    echo "" >> source_this.bash && \
    echo "# tempo2" >> source_this.bash && \
    echo "export TEMPO2=\$PSRHOME/tempo2/T2runtime" >> source_this.bash && \
    echo "export PATH=\$PATH:\$TEMPO2/bin" >> source_this.bash && \
    echo "export C_INCLUDE_PATH=\$C_INCLUDE_PATH:\$TEMPO2/include" >> source_this.bash && \
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$TEMPO2/lib" >> source_this.bash && \
    echo "" >> source_this.bash && \
    echo "# tempo2" >> source_this.bash && \
    echo "export TEMPO2=\$PSRHOME/tempo2/T2runtime" >> source_this.bash && \
    echo "export PATH=\$PATH:\$TEMPO2/bin" >> source_this.bash && \
    echo "export C_INCLUDE_PATH=\$C_INCLUDE_PATH:\$TEMPO2/include" >> source_this.bash && \
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$TEMPO2/lib" >> source_this.bash && \
    echo "export PYTHONPATH=\$PYTHONPATH:\$PSRCHIVE/install/lib/python3.6/site-packages/" >> source_this.bash && \
    echo "" >> source_this.bash && \
    echo "# DSPSR" >> source_this.bash && \
    echo "export DSPSR=\$PSRHOME/dspsr" >> source_this.bash && \
    echo "export PATH=\$PATH:\$DSPSR/install/bin" >> source_this.bash && \
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$DSPSR/install/lib" >> source_this.bash && \
    echo "export C_INCLUDE_PATH=\$C_INCLUDE_PATH:\$DSPSR/install/include" >> source_this.bash && \
    echo "" >> source_this.bash
CMD ["bash"]
