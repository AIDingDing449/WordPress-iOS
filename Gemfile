# frozen_string_literal: true

source 'https://rubygems.org'

gem 'danger-dangermattic', '~> 1.2'
gem 'dotenv'
# 2.223.1 includes a fix for an ASC-interfacing issue
#
# See failures like https://buildkite.com/automattic/wordpress-ios/builds/24053#019234f2-80a5-40f6-b55e-2f420e6483a8/3840-3915
# and https://github.com/fastlane/fastlane/pull/22256
gem 'fastlane', '~> 2.228'
gem 'fastlane-plugin-firebase_app_distribution', '~> 0.10'
gem 'fastlane-plugin-sentry'
# This comment avoids typing to switch to a development version for testing.
#
# gem 'fastlane-plugin-wpmreleasetoolkit', git: 'https://github.com/wordpress-mobile/release-toolkit', ref: ''
gem 'fastlane-plugin-wpmreleasetoolkit', '~> 13.3'
gem 'rake'
gem 'rubocop', '~> 1.78'
gem 'rubocop-rake', '~> 0.7'
gem 'xcpretty-travis-formatter'

group :screenshots, optional: true do
  gem 'rmagick', '~> 6.1.1'
end
