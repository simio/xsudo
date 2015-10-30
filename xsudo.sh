#!/bin/sh
#
# xsudo.sh v1.4 2015-10-30, jesper at huggpunkt.org
# Usage is 'xsudo.sh [-t] [-u user] <command>'
#
# Grants access for <user> to DISPLAY and uses sudo to run <command>
# as that user.
#
# 	-t
#		Use a trusted MIT cookie instead of an untrusted. This enables
#		X11 extensions, which on the one hand enables accelerated
#		graphics and unbreaks the ISO_Level3_Shift (Alt Gr) modifier,
#		but on the other hand allows the invoked command to access every
#		X11 event, essentially obliterating inter-program security.
#
#	-u <user>
#		Use sudo to impersonate <user> instead of the super-user.
#		If the specified user does not exist, xsudo.sh exits with 1.

##
##	CONFIGURATION
##
##	You might need to adapt the stuff below to your system.
##

# Set this variable here or in your environment
# If using doas instead of sudo, don't forget to change WHICH_SUDO
#XSUDO_USE_DOAS=Yes

# Locations. Use full paths!
WHICH_SUDO=/usr/local/bin/sudo
WHICH_ASKPASS=/usr/X11R6/bin/ssh-askpass
WHICH_USERINFO=/usr/sbin/userinfo
WHICH_XAUTH=/usr/X11R6/bin/xauth
WHICH_MKTEMP=/usr/bin/mktemp
WHICH_CHOWN=/sbin/chown

# Value for homedir for users without one
NO_HOME_DIR=/var/empty

# Unix group of root
WHEEL=wheel

# Exits with 1 if the specified user does not exist
user_exists () {
	$WHICH_USERINFO -e "$USERNAME"
	[ X$? != X0 ] && echo "$0: no such user: $USERNAME" 1>&2 && exit 1
}

# Put home dir of $USERNAME in USER_HOME
USER_HOME=""
get_user_home () {
	USER_HOME=$($WHICH_USERINFO "$USERNAME" \
		| grep dir \
		| sed 's,[^/]*\(.*\)$,\1,')
}

##
##	End of configuration
##

TRUST=untrusted
USERNAME=root

args=$(getopt tu: $*)
if [ $? -ne 0 ]; then
	echo "Usage: $0 [-t] [-u <user>] command ..." 1>&2
	echo 1>&2
	echo "    -t  Use trusted authentication cookie" 1>&2
	echo "    -u  Impersonate <user> instead of root" 1>&2
	echo 1>&2
	exit 2
fi
set -- $args
while [ $# -ge 0 ]; do
	case "$1" in
		-t)
			TRUST=trusted
			shift;;
		-u)
			USERNAME="$2"
			shift; shift;;
		--)
			shift; break;;
	esac
done

export SUDO_ASKPASS=$WHICH_ASKPASS

# Exit if user doesn't exist
user_exists "$USERNAME"

# Get USER_HOME dir
get_user_home "$USERNAME"

if [ X$XSUDO_USE_DOAS != X ]; then
	SUDO_PARAMS=-u
	SUDO_A_PARAM=""
else
	SUDO_A_PARAM="-A"
	if [ X$USER_HOME != X$NO_HOME_DIR -a X$USER_HOME != X ]; then
		SUDO_PARAMS=-AHu
	else
		SUDO_PARAMS=-Au
	fi
fi

umask 077
NEW_XAUTHORITY=$($WHICH_MKTEMP "/tmp/$USERNAME"_xauth.XXXXXXXX)
$WHICH_XAUTH -f $NEW_XAUTHORITY generate $DISPLAY . $TRUST
$WHICH_SUDO $SUDO_A_PARAM /bin/sh -c "( \
	$WHICH_CHOWN $USERNAME.$WHEEL $NEW_XAUTHORITY; \
	$WHICH_SUDO $SUDO_PARAMS $USERNAME \
		env DISPLAY=$DISPLAY \
		env XAUTHORITY=$NEW_XAUTHORITY \
		$*; \
	rm -f $NEW_XAUTHORITY \
)"
