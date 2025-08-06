#import "@preview/cheq:0.2.2": checklist
#import "@preview/tablem:0.2.0": tablem, three-line-table
#import "@preview/shadowed:0.2.0": shadowed as shadowed-original


#let shadowed(dark-mode: false, ..args) = shadowed-original(
  radius: 4pt,
  inset: 12pt,    
  fill: if dark-mode { gray.darken(90%) } else { white },
  ..args
)


#let my-config(
  doc
) = {

  set text(font: (
    "Fira Sans",
    "Atkinson Hyperlegible Next",
    "Atkinson Hyperlegible",
    "Libertinus Serif")
  )

  set par(justify: true)
  
  show: checklist.with(
    marker-map: (
      " ": sym.ballot,
      "x": sym.ballot.cross,
      "-": sym.bar.h,
      "/": sym.slash.double
    )
  )
  
  doc
}
