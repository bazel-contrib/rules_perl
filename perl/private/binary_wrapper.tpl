#!/bin/sh

if [ -n "${RUNFILES_DIR+x}" ]; then
  PATH_PREFIX=$RUNFILES_DIR/{workspace_name}/
elif [ -s `dirname $0`/../../MANIFEST ]; then
  PATH_PREFIX=`cd $(dirname $0); pwd`/
elif [ -d $0.runfiles ]; then
  PATH_PREFIX=`cd $0.runfiles; pwd`/{workspace_name}/
else
  PATH_PREFIX=./
fi

export PERL5LIB="$PERL5LIB{PERL5LIB}"

{env_vars} $PATH_PREFIX{interpreter} -I${PATH_PREFIX} ${PATH_PREFIX}{main} "$@"
