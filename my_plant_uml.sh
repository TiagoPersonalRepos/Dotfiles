# plant_uml_jar_url="https://github.com/plantuml/plantuml/releases/download/snapshot/plantuml-SNAPSHOT.jar"
# wget $plant_uml_jar_url
# sudo apt install graphviz default-jre
java -jar <path-to>/plantuml-SNAPSHOT.jar --output-dir $(pwd) "$@"