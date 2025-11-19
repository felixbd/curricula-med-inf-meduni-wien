
# nix --extra-experimental-features "nix-command flakes" run github:typst/typst -- compile \
#  --pdf-standard a-1b \  # or use a-3b
#  --input date="`date`" \

c:
	typst compile main.typ

w:
	typst watch main.typ

o: open

open:
	xdg-open ./main.pdf

t: thumbnail

thumbnail:
	typst compile --root=. -f png --pages 1 --ppi 250 ./main.typ ./thumbnail.png

clean:
	rm -fr ./*.pdf
