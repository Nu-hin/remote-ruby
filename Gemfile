source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gemspec

group :development do
  gem 'rubocop'
  gem 'yard'
end

group :development, :test do
  gem 'byebug', '>= 8.0'
  gem 'pry-byebug'
  gem 'rspec', '~> 3.0'
end

group :test do
  gem 'coveralls', require: false
end
