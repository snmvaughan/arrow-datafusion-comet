SPARK_BASE=.

sed -i.bak -E 's/com.apple.pie.boson/org.apache.comet/g' $SPARK_BASE/pom.xml
sed -i.bak -E 's/boson/comet/g' $SPARK_BASE/pom.xml

sed -i.bak -E 's/com.apple.pie.boson/org.apache.comet/g' $SPARK_BASE/sql/core/pom.xml
sed -i.bak -E 's/boson/comet/g' $SPARK_BASE/sql/core/pom.xml

BOSON_FILES=$(find $SPARK_BASE \( -name "*.java" -o -name "*.scala" -o -name "*.xml" \) | xargs grep -l boson)
for file in $BOSON_FILES; do
  sed -i.bak -E 's/com.apple.boson/org.apache.comet/g' $file
  sed -i.bak -E 's/org.apache.spark.sql.boson/org.apache.spark.sql.comet/g' $file
  sed -i.bak -E 's/spark.boson/spark.comet/g' $file
  sed -i.bak -E 's/Boson/Comet/g' $file
done

find $SPARK_BASE -name "*.bak" | xargs rm -f {} \;
