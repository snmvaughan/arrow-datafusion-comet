#!/bin/sh
set -e

# Helper script to install Boson and Spark in Rio
SCRIPT_NAME=$(echo $0 | sed 's/.*\///')

function usage() {
  echo "Usage: $SCRIPT_NAME [--use-existing-boson <version>] [<spark-branch>]"
  echo "       $SCRIPT_NAME -h|--help"

}

function usageAndExit(){
  usage
  exit 0
}

# complain to STDERR and exit with error
die() {
  echo "$*" >&2;
  exit 2;
}

BASEDIR=$(readlink -f "$(dirname $0)")
BOSON_VERSION=""
BOSON_WORKSPACE=$(cd $BASEDIR/..; pwd)

SKIP_BOSON=false
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usageAndExit
      ;;
    --use-existing-boson)
      SKIP_BOSON=true
      BOSON_VERSION=$2
      shift 2
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      break;
      ;;
  esac
done

if [ -z "$BOSON_VERSION" ]; then
  BOSON_VERSION=$($BOSON_WORKSPACE/mvnw -nsu -q $PROFILES help:evaluate -Dexpression=project.version -DforceStdout 2>/dev/null)
fi
SPARK_VERSION=$(./mvnw -nsu -q $PROFILES help:evaluate -Dexpression=spark.version -DforceStdout)
SPARK_PATCH_VERSION=$(echo $SPARK_VERSION | sed -E 's/([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
SPARK_BRANCH=${1:-"branch-${SPARK_PATCH_VERSION}-apple"}
SCALA_BINARY_VERSION=$($BOSON_WORKSPACE/mvnw -nsu -q $PROFILES help:evaluate -Dexpression=scala.binary.version -DforceStdout 2>/dev/null)
SCALA_VERSION=$($BOSON_WORKSPACE/mvnw -nsu -q $PROFILES help:evaluate -Dexpression=scala.version -DforceStdout 2>/dev/null)

if [ $SKIP_BOSON = "true" ]; then
  echo Skipping boson build...
else
  make clean release
fi

set -x

# Removing local cached parquet artifacts since they don't include test jars, which
# could cause issues later when building Spark with SBT
rm -rf /root/.m2/repository/org/apache/parquet
# Removing local cached protobuf that also causes building Spark with SBT
rm -rf /root/.m2/repository/com/google/protobuf

cd $BOSON_WORKSPACE
rm -rf apache-spark
git clone git@github.pie.apple.com:IPR/apache-spark.git --depth 1 --branch $SPARK_BRANCH
cd apache-spark

# Apply custom diff files, if they exist
if [ -f "$BASEDIR/diff/$SPARK_BRANCH.diff" ]; then
  git apply "$BASEDIR/diff/$SPARK_BRANCH.diff"
fi

# Update the Boson version
$BOSON_WORKSPACE/mvnw -nsu -q versions:set-property -Dproperty=boson.version  -DnewVersion=$BOSON_VERSION -DgenerateBackupPoms=false

# Update the Scala version
dev/change-scala-version.sh $SCALA_BINARY_VERSION

# FIXME Temporary work around for excluded javax.servlet
sed -i.bak -E '0,/javax.servlet/{s/^( *)(ExclusionRule\("javax.servlet")/\1\/\/\2/}' project/SparkBuild.scala 

# Use an internal Docker Hub mirror to enable Rio 3 builds
find resource-managers/kubernetes -name Dockerfile | xargs -n 1 sed -i.bak 's|^FROM |FROM docker-upstream.apple.com/|'

# Store the Boson parameters
cat > boson-parameters.sh <<EOD
export BOSON_WORKSPACE=$BOSON_WORKSPACE
export BOSON_VERSION=$BOSON_VERSION
export SCALA_VERSION=$SCALA_VERSION
export SCALA_BINARY_VERSION=$SCALA_BINARY_VERSION
EOD
chmod a+x boson-parameters.sh
