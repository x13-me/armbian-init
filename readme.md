
# DO NOT MERGE

# [`x13-me`](https://github.com/x13-me)/[`armbian-init`](https://github.com/x13-me/armbian-init.git)

------

## About

[`armbian-init`](/armbian-init.sh) serves to replace [`armbian-firstlogin`](https://github.com/armbian/build/blob/main/packages/bsp/common/usr/lib/armbian/armbian-firstlogin) from [armbian/build/blob/main/packages/bsp/common/usr/lib/armbian/armbian-firstlogin](https://github.com/armbian/build/blob/main/packages/bsp/common/usr/lib/armbian/)

------

## Notes

- feature-parity is the initial aim, with stretch goals of additional config options

- an emphasis is being made towards code-safety, i.e. config files are no longer blindly sourced, but loaded into an array programmatically

- where possible, config*ng* will be used, in favour of directly manipulating the system

- see [.plan](/.plan) for, well, the plan

------

### Author's note

I am **not** an experienced developer, whilst effort is made to ensure code safety:

# DO *NOT* MERGE

this code is not even ready for review yet.
