JAR := berkeley-entity-1.0.jar

all: data/gender.data data/bllip-clusters lib/CorScorer.pm lib/Algorithm

# Number and gender data
data/gender.data:
	@mkdir -p $(@D)
	curl -s http://www.cs.utexas.edu/~gdurrett/data/gender.data.tgz | tar xz -C data

# Brown clusters
data/bllip-clusters:
	@mkdir -p $(@D)
	curl -s http://people.csail.mit.edu/maestro/papers/bllip-clusters.gz | gunzip > $@

# CoNLL scorer
scorer/v7/lib/CorScorer.pm scorer/v7/lib/Algorithm:
	curl -s http://conll.cemantix.org/download/reference-coreference-scorers.v7.tar.gz | tar xz
	mv reference-coreference-scorers scorer

lib/CorScorer.pm: scorer/v7/lib/CorScorer.pm
	cp $< $@

lib/Algorithm: scorer/v7/lib/Algorithm
	cp -R $< $@

models:
	curl -s http://nlp.cs.berkeley.edu/downloads/berkeley-entity-models.tgz | tar xz

# Preprocess the data, no NER
%/preprocessed: %/text
	@mkdir -p $@ test/scratch
	# RUNNING PREPROCESSING
	java -Xmx2g -cp $(JAR) edu.berkeley.nlp.entity.preprocess.PreprocessingDriver ++config/base.conf \
    -execDir test/scratch/preprocess \
    -inputDir $< -outputDir $@

# The following commands demonstrate running:
# 1) the coref system in isolation
# 2) the coref + NER system
# 3) the full joint system
# Note that the joint system does not depend on either of the earlier two;
# this is merely meant to demonstrate possible modes of operation.

# Run the coreference system
%/coref: %/preprocessed
	@mkdir -p $@ test/scratch
	# RUNNING COREF
	java -Xmx2g -cp $(JAR) edu.berkeley.nlp.entity.Driver ++config/base.conf \
    -execDir test/scratch/coref \
    -mode COREF_PREDICT \
    -modelPath models/coref-onto.ser.gz \
    -testPath $< \
    -outputPath $@ \
    -corefDocSuffix ""

# Run the coref+NER system
%/corefner: %/preprocessed
	@mkdir -p $@ test/scratch
	# RUNNING COREF+NER
	java -Xmx6g -cp $(JAR) edu.berkeley.nlp.entity.Driver ++config/base.conf \
    -execDir test/scratch/corefner \
    -mode PREDICT \
    -modelPath models/corefner-onto.ser.gz \
    -testPath $<
	cp test/scratch/corefner/output*.conll $@

# Run the full joint system
# Now run the joint prediction
%/joint: %/preprocessed
	@mkdir -p $@ test/scratch
	# RUNNING COREF+NER+WIKI
	java -Xmx8g -cp $(JAR) edu.berkeley.nlp.entity.Driver ++config/base.conf \
    -execDir test/scratch/joint \
    -mode PREDICT \
    -modelPath models/joint-onto.ser.gz \
    -testPath $< \
    -wikipediaPath models/wiki-db-test.ser.gz
	cp test/scratch/joint/output*.conll $@

models/wiki-db-test.ser.gz: data/wikipedia/enwiki-latest-pages-articles.xml
	# First, need to extract the subset of Wikipedia relevant to these documents. We have already
	# done this to avoid having. Here is the command used:
	java -Xmx4g -cp $(JAR):lib/bliki-resources edu.berkeley.nlp.entity.wiki.WikipediaInterface \
    -datasetPaths test/preprocessed \
    -wikipediaDumpPath $< \
    -outputPath $@
