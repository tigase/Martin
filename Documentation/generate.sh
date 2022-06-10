#
# Tigase Swift Library - Documentation - bootstrap configuration for all Tigase projects
# Copyright (C) 2004 Tigase, Inc. (office@tigase.com) - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary and confidential
#

mkdir target
asciidoctor -D target asciidoc/index.asciidoc
asciidoctor-pdf -D target asciidoc/index.asciidoc
asciidoctor-epub3 -D target asciidoc/index.asciidoc
