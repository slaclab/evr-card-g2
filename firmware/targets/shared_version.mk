# Bypass lcls-timing-core@v3.10.0 updates the surf lock to v2.53.0
# This v2.53.0 requirement is due to the change for GTH/GTY
# This project does not use GTH/GTY (only GTX)
# Upgrading surf from v2.8.0 to v2.53.0 has a lot of risk and
# will require a lot of regression. To avoid this risk for now,
# we are going to bypass this submodule lock understanding that
# we will need to upgrade surf in a future release
export OVERRIDE_SUBMODULE_LOCKS=1

# Define Firmware Version Number
export PRJ_VERSION = 0xCED20037

# Define RELEASE variable
export RELEASE = all
