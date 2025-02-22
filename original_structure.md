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

- define repeats=3
- if config file exists
  - if username not preset
    - prompt for `username`
  - if username not preset
    - read `username` from stdin
  - else set `username` to preset
  - test for illegal chars in username, return if any
  - set `RealUserName` to `username` - only alphanumeric chars, all lowercase
  - if `RealUserName` is unset return
  - if `RealUserName` exists throw error
- if config file exists
  - if password not preset
    - call `read_password`
    - echo blank line
  - else set `password` to preset
  - set `first_input` to `password`
  - if password not preset
    - call `read_password` _again_
    - echo blank line
  - set `second_input` to `password`
  - if `first_input` equals `second_input`
    - if `cracklib-check` is present
      - set `result` to `cracklib-check` check on `password`
      - set `okay` to parsed output
      - if `okay` not "OK" warn of weak password
    - if realname not preset
      - echo blank line
      - prompt for `RealName`
    - else set `RealName` to preset
    - call `adduser` to create new user
    - if ssh key preset
      - create `~/.ssh/`
      - curl `PRESET_ROOT_KEY` to created user's home dir
      - change ownership of `~/.ssh` to created user
    - if `first_input` nonzero
      - echo `first_input` and `second_input` to `passwd`
    - else delete password for created user
    - add user to groups:
      - `sudo`
      - `netdev`
      - `audio`
      - `video`
      - `disk`
      - `tty`
      - `users`
      - `games`
      - `dialout`
      - `plugdev`
      - `input`
      - `bluetooth`
      - `systemd-journal`
      - `ssh`
      - `render`
    - create `~/.Xauthority`
    - `chown` `~/Xauthority`
    - ##L605 -- [menu's note: haven't parsed this yet]
    - get `RealName` from `/etc/passwd` `RealUserName` entry
    - ##L605 -- [menu's note: possibly parsed, unsure? seeking clarification]
    - if `RealName` is zero-len set `RealName` to `RealUserName`
    - notify user of account creation and details
    - delete config file
    - make `/etc/update-motd.d/*/ executable
    - if `psd` (Profile Sync Daemon) is present
      - add `psd-overlay-helper` to `/etc/sudoers` with `NOPASSWD`
      - touch `~/.activate_psd`
      - `chown` `~/.activate_psd`
    - **BREAK**
  - elif `password` non-zero
    - warn user passwords do not match
    - reduce `REPEATS` by 1
  if `REPEATS` is zero `logout`

- if config file exists

>> ##EXPLICIT note: what the fuck? why are we testing if the file exists four times in the same script? this is no bueno
> implementation note: config should be loaded in, a bool _could_ be used, but it's likely unnecessary
>> menu's note: i don't want to scream-test any of this, but i'm unsure if it's all actually _necessary_, so it'll probably get poorly reimplemented

### process config

- if config exists AND we're in a tty
  - source config
  > implementation note: this is dangerous, we don't want to do this
  - if `PRESET_CONFIGURATION` is set
    - curl `PRESET_CONFIGURATION` to config location
    > implementation note: this does not allow for split-config
  - call `do_firstrun_automated_network_config`
  - remove getty `override.conf`
  - remove serial-getty `override.conf`
  - reload systemd
  > menu's note: this... doesn't seem great
  - set `desktop_dm` to `none`
  - set `desktop_is_sddm`, `desktop_is_lightdm`, `desktop_is_gdm3` to `0`
  - if `/usr/sbin/sddm` exists
    - set `desktop_dm` to `sddm`
    - set `desktop_is_sddm` to `1`
  - if `/usr/sbin/lightdm` exists
    - set `desktop_dm` to `lightdm`
    - set `desktop_is_lightdm` to `1`
  - if `/usr/sbin/gdm3` exists
    - set `desktop_dm` to `gdm3`
    - set `desktop_is_gdm3` to `1`
  > implementation note: this should probably be case/switch, to ensure no undefined state
  - notify user we're waiting for system to finish booting
  - _actually_ wait for boot to finish
  - if framebuffer width is greater than 1920
    - if `/etc/lightdm/slick-greeter.conf` exists
      - append `enable-hidpi = on`
    - if `/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml` exists
      - set `WindowScalingFactor` to `2`
    - set font to `/usr/share/consolefonts/Uni3-TerminusBold32x16.psf.gz`
  - clear screen
  - if `VENDORPRETTYNAME` is set, set `VENDOR` to it
  - welcome user
  - echo blank line
  - call `get_local_ip_addr`
  - if `PRESET_ROOT_PASSWORD` not set, echo empty line
  - trap `SIGINT` with no-op
  - set `REPEATS` to `3`
  - if config file exists
    - source config
    > ##Explicit note: again, what the fuck? why are we source the config _again_?
    
