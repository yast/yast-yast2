FROM yastdevel/ruby-tw
COPY . /tmp/sources
# English messages, UTF-8, "C" locale for numeric formatting tests
ENV LC_ALL= LANG=en_US.UTF-8 LC_NUMERIC=C

