
all : book

clean :
	rm -f docs/index.html
	rm -f bin/sample-code-checker

test : cpptest texttest

texttest : *.md
	textlint -f unix *.md

cpptest : test-tool
	bin/sample-code-checker *.md

retest : test-tool
	bin/sample-code-checker retest /tmp/sample-code-checker/*.cpp

test-tool : bin/sample-code-checker

bin/sample-code-checker : bin/sample-code-checker.cpp
	g++ -D _ISOC11_SOURCE -std=c++14 --pedantic-errors -Wall -pthread -O2 -o bin/sample-code-checker  bin/sample-code-checker.cpp

book : docs/index.html docs/index_en.html


docs/index.html : ja/*.md style.css
	pandoc -s --toc --toc-depth=6 --mathjax -o $@ -H style.css  ja/pandoc_title_block ja/*-*.md

docs/index_en.html : en/*.md style.css
	pandoc -s --toc --toc-depth=6 --mathjax -o $@ -H style.css  en/pandoc_title_block en/*-*.md


.PHONY : all book clean test test-tool texttest cpptest retest
