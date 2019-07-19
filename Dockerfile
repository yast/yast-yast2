# Use this base image
# - built: https://registry.opensuse.org
# - source: https://github.com/yast/ci-ruby-container
FROM registry.opensuse.org/yast/head/containers/yast-ruby
# ruby-bindings that include RBIs
RUN zypper ar --refresh https://download.opensuse.org/repositories/home:/mvidner:/branches:/YaST:/Head/openSUSE_Tumbleweed mvyast
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends --allow-vendor-change \
  yast2-ruby-bindings
COPY . /usr/src/app
# sorbet itself, also make Gemfile.lock match
RUN bundle update
# let it find RBIs that come from RPMs (not from gems)
RUN find /usr/share/YaST2/rbi -name \*.rbi > sorbet/list_of_rbis
# English messages, UTF-8, "C" locale for numeric formatting tests
ENV LC_ALL= LANG=en_US.UTF-8 LC_NUMERIC=C

