# `original_structure.md`

Plaintext description of each function in [.plan](./.plan)

## Functions

### source release files

this is run blindly outside of any function, we don't like this

- - we likely want to import these as variables in an array

- `import /etc/lsb-release`
- `import /etc/os-release`
- `set DISTRIB_CODENAME`
- `set DISTRIBUTION_STATUS`
- `import /etc/armbian-release`

### `check_abort`

called on [L#765](./original_armbian-firstlogin#L765) trapping SIG INT

- - This is run _immediately_ upon hitting Ctrl-C
- - Probably undesirable in init
- notify user about cancellation
- remove config
- check shell
- if shell is zsh, notify user to relog
- catch SIG INT
- quit

### `mask2cidr`

called on [L#95](./original_armbian-firstlogin#L95)

- - appears to be for backwards compatibility with previous config
- - This is NOT desirable in init
- - Kinda wonky method to convert a subnet mask to CIDR
- for each part of given mask:
- case/switch statement using hard-coded conversion
- - potentially invalid config?
- echoes number of set bits?

### `createYAML`

called on:

- [L#119](./original_armbian-firstlogin#L119)
- [L#130](./original_armbian-firstlogin#L130)

- - generates a netplan
- - NOT desirable
- creates YAML for networking
- printfs YAML

### `do_firstrun_automated_network_configuration`

called on [L#636](./original_armbian-firstlogin#L636)

- - see .plan for potential implementation?
- - inexplicably:
- test if config file exists, do nothing if not
- remove \r from config
- read but don't execute, exit on fail
- - validates that it's at least bash
- source file blindly
- format DNS+MASK vars
- - we really don't need this
- - interactive network config generator??
- test if change settings, do nothing if not
- get name of first ethernet
- get name of first wifi
- - this is _probably_ bad?
- - we want to configure _all_ adapters
- set config name -{dhcp|static}
- check network device actually exists
- if wifi config enabled create wifi config
- elif eth config enabled create eth config
- - we want to offer config for _all_ network adapters

### `get_local_ip_addr`

called on [L#143](./original_armbian-firstlogin#L143)

- try get local IP using:
  `ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | awk '{$1=$1}1' FS='\n' OFS=',' RS=`
- - can probably be used verbatim, though there's probably a more reliable way - this should be investigated

### `read_password`

called on:

- [L#552](./original_armbian-firstlogin#L552)
- [L#559](./original_armbian-firstlogin#L559)
- [L#691](./original_armbian-firstlogin#L691)
- [L#712](./original_armbian-firstlogin#L712)

- set `prompt`

- enable input echo
- - why is unclear, we _don't_ want this?
- nonsense to handle backspace
- - we should call `passwd` interactively, and not store sensitive data

### `set_shell`

called on [L#762](./original_armbian-firstlogin#L762)

- read list of shells into array $optionsAudits
- test if this array is longer than 1
- - some extreme nonsense to handle arrays being zero-indexed
- - this shouldn't be necessary in the slightest
- - we likely want to only match `/bin/<shell>` anyway
- notify user which shell is set
- `chsh`current user shell to set shell
- change shell in `/etc/default/useradd`
- change shell in `/etc/adduser.conf`

### `set_timezone_and_locales`

called on [L#776](./original_armbian-firstlogin#L776)

- - this whole function is quite broken, the logic doesn't make much sense, and there's multiple network calls
- - this will **definitely** be refactored
- grab public IP address from `ipinfo.io`
- if this fails, check if a wifi adapter exists
  - Notify user no connection is detected
  - check if `PRESET_CONNECT_WIRELESS`is set
    - if not, ask the user if they'd like to connect
  - if we're connecting, ask the user which wifi adapter to use
- - we probably want to replace this with an interactive network config, which should come before we use networking
  - generate netplan config for wifi
  - - yada yada yada, this is all network config
- grab public IP again
- grab IP json from IP
- - this is daft, just grab the json without specifying IP
- parse json into individual variables
- concat variables into `TIMEZONE`,`COUNTRY` and `COUNTRYCODE`
  - parse `TZDATA`
  - parse `CCODE`
- - this is nonsense, casting json into array is safer
- - this code will break if ipinfo doesn't return timezone
- check if `SET_LANG_BASED_ON_LOCATION` is unset **and** `TZDATA` is nonzero
  - notify user of detected timezone
  - set `response` var to Y
- otherwise set `response` to `SET_LANG_BASED_ON_LOCATION`
- check if `response` is _no_
  - unset `CCODE` and `TZDATA`
- - all of this should be skipped if it's not supposed to be set
- - the following can be replaced with a single call to configng
- get locales
- check `PRESET_LOCALE` is unset
  - prompt user to select from list of possible locales
  - - surely there's an interactive?
- sets `LOCALES` to a single value
- check for `*Skip*` in `LOCALES`
  - if `PRESET_TIMEZONE` unset, prompt to `tzselect`
  - - we can still hook tzselect, or configng
  - if set, set `TZDATA`
  - set timezone
  - reconfigure dpkg for new timezone
  - change default loacle
  - generate locales
  - set detected locale environment variables
  - - only set in `.{bash,xsession}rc`, not `.zshrc`
  - - we should probably set this through `/etc/profile`
  - - see `man profile`

### `add_profile_sync_settings`

never called.

> menu's note: i'm not actually sure this code works? it doesn't appear to ever be called

- check if `/usr/bin/psd` exists
  - return if it doesn't
- run `/usr/bin/psd`, send output to `/dev/null`
- set `config_file` to `~/.config/psd/psd.conf`
- if config file exists
  - enable overlayfs in `config_file`
  - check if overlayfs is enabled
    - notify user
    - disable in config if not
- enable `psd.service`
- start `psd.service`

> implementation note: this should probably be handled by `/etc/profile` and not firstboot, it is necessary to perform for each new user

### `add_user`

> menu's note: i don't want to scream-test any of this, but i'm unsure if it's all actually _necessary_, so it'll probably get poorly reimplemented

### process config

- test if config exists and we're in a tty

- source config
- - this is dangerous, we don't want to do this
