# SemanticCli

A Ruby DSL for building flag-free CLIs. You define named functions that return shell commands — the framework takes care of parsing, argument resolution, and piping.

```
watch log v2ray grep error
→ Running: tail -f /usr/local/etc/v2ray/share.log | grep error
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

fn('v2ray') do
  if macos?
    "brew services restart v2ray"
  else
    "sudo systemctl restart v2ray"
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
      restart v2ray → restart v2ray service
      restart psql  → restart postgresql
  HELP
end

run
```

Then just run: `restart v2ray`

### DSL

- `fn(name) { |arg| "shell command" }` — define a function that returns a shell command string
- `cmd(name, command)` — shorthand when no logic is needed
- `fn('') { "help text" }` — help text, displayed when no arguments are given
- `macos?` / `linux?` — platform detection helpers

### Argument Styles

```ruby
fn('log') { |svc| "journalctl -u #{svc} -f" }              # required arg:  watch log v2ray
fn('http') { |site='google'| "curl #{site}.com" }           # optional arg:  watch http / watch http github
fn('dns') { |c1, *rest| "dig #{c1} #{rest.join(' ')}" }     # rest args:     dns set 8.8.8.8 8.8.4.4
fn('status') { "kubectl get pods" }                          # no arg:        ops status
cmd 'deploy', 'kubectl rollout restart deployment'           # static string: ops deploy
```

### Piping

When multiple functions are chained, their outputs are joined with `|`:

```
watch log v2ray grep error
→ Running: journalctl -u v2ray -f | grep error
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
cmd '77', 'ssh root@192.168.77.1'
cmd '7744', 'ssh root@lzm -p 7744'
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

Write scripts that work on both macOS and Linux:

```ruby
fn('proxy') do |c1='display'|
  if macos?
    "networksetup -setsocksfirewallproxystate wifi #{c1}"
  else
    "gsettings set org.gnome.system.proxy mode manual"
  end
end
```

## Development

```bash
bin/setup        # install dependencies
rake test        # run tests
bin/console      # interactive prompt
```

## License

MIT
