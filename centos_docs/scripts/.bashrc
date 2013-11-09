# .bashrc


# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

shopt -s expand_aliases

ulimit -c unlimited

# User specific aliases and functions
# User specific aliases and functions
PATH==$PATH:/sbin:/usr/sbin:/home/nareshapp/scripts
CDPATH=.:/home/Views/nappann_r145_view:/home/Views/nappann_r145_view/nextgen:/home/Views/nappann_r145_view/nextgen/products:/home/Views/nappann_r145_view/nextgen/lib:/home/Views/nappann_r145_view/nextgen/ansoftcore/lib:/home/Views/nappann_r145_view/nextgen/ansoftcore/products:/home/nareshapp:/home/nareshapp/programs:/home/nareshapp/programs/AnsysEM/designer8.0:/home:/home/networkdisk3:/home/nareshapp/software

# Aliases
source /home/nareshapp/aliases
