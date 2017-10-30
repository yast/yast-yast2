# Use this base image
# - built: https://hub.docker.com/r/yastdevel/ruby/
# - source: https://github.com/yast/docker-yast-ruby
FROM yastdevel/ruby
COPY . /usr/src/app
# English messages, UTF-8, "C" locale for numeric formatting tests
ENV LC_ALL= LANG=en_US.UTF-8 LC_NUMERIC=C

