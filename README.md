# SemanticCli

A Ruby DSL for building flag-free CLIs. You define named functions that return shell commands — the framework takes care of parsing, argument resolution, and piping.

```
watch log nginx grep error
→ Running: tail -f /var/log/nginx/access.log | grep error
```

## Installation

```bash
gem install semantic_cli
```

## Usage

Create a script (e.g., `restart`):

```ruby
#!/usr/bin/env ruby
require 'semantic_cli'

fn('nginx') do
  if macos?
    "brew services restart nginx"
  else
    "sudo systemctl restart nginx"
  end
end

fn('psql') do
  if macos?
    "brew services restart postgresql@15"
  else
    "sudo systemctl restart postgresql"
  end
end

fn('') do
  <<~HELP
    Examples:
      restart nginx → restart nginx service
      restart psql  → restart postgresql
  HELP
end

run
```

Then just run: `restart nginx`

### DSL

- `fn(name) { |arg| "shell command" }` — define a function that returns a shell command string
- `cmd(name, command)` — shorthand when no logic is needed
- `fn('') { "help text" }` — help text, displayed when no arguments are given
- `macos?` / `linux?` — platform detection helpers

### Argument Styles

```ruby
fn('log') { |svc| "journalctl -u #{svc} -f" }              # required arg:  watch log nginx
fn('http') { |site='google'| "curl #{site}.com" }           # optional arg:  watch http / watch http github
fn('dns') { |c1, *rest| "dig #{c1} #{rest.join(' ')}" }     # rest args:     dns set 8.8.8.8 8.8.4.4
fn('status') { "kubectl get pods" }                          # no arg:        ops status
cmd 'deploy', 'kubectl rollout restart deployment'           # static string: ops deploy
```

### Piping

When multiple functions are chained, their outputs are joined with `|`:

```
watch log nginx grep error
→ Running: journalctl -u nginx -f | grep error
```

### Key-Value Syntax

Arguments can also be passed with `key:value`:

```
watch max:5
→ Running: head -n5
```

## Use Cases

### Personal Command Palette

Wrap the commands you use every day into short, memorable names:

```ruby
cmd 'dev', 'ssh user@dev-server'
cmd 'db', 'ssh user@db-server -p 3322'
```

### DevOps Runbook

Turn team runbooks into executable scripts instead of wiki pages people copy-paste from:

```ruby
fn('deploy') { |env| "kubectl rollout restart deployment/app -n #{env}" }
fn('logs') { |svc| "kubectl logs -f deployment/#{svc} --tail=100" }
fn('status') { "kubectl get pods -A" }
```

`ops deploy staging`, `ops logs api`, `ops status` — the team doesn't need to remember the underlying commands.

### Cross-Platform Scripts

Write scripts that work on both macOS and Linux — see [examples/wifi](examples/wifi) for a complete example covering proxy, DNS, platform detection, and rest args.

## Development

```bash
bin/setup        # install dependencies
rake test        # run tests
bin/console      # interactive prompt
```

## License

MIT
