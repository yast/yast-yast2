# Use this base image
# - built: https://registry.opensuse.org
# - source: https://github.com/yast/ci-ruby-container
FROM registry.opensuse.org/yast/sle-15/sp2/containers/yast-ruby
COPY . /usr/src/app
# English messages, UTF-8, "C" locale for numeric formatting tests
ENV LC_ALL= LANG=en_US.UTF-8 LC_NUMERIC=C

