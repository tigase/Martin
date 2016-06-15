mkdir target
asciidoctor -D target asciidoc/index.asciidoc
asciidoctor-pdf -D target asciidoc/index.asciidoc
asciidoctor-epub3 -D target asciidoc/index.asciidoc
