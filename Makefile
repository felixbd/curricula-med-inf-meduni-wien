


c:
	typst compile main.typ

w:
	typst watch main.typ

t: thumbnail

thumbnail:
	typst compile --root=. -f png --pages 1 --ppi 250 ./main.typ ./thumbnail.png

clean:
	rm -fr ./*.pdf
