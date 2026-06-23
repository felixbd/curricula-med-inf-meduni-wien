#set page(width: auto, height: auto)

#set enum(numbering: "I. 1. a.)")

#set text(
  lang: "en",
  region: "gb",
  slashed-zero: true
)


#let data = toml("a.toml")


= Blocks with lectures

#for block in data.at("block", default: none) [
  + #block.name
    #for lecture in block.at("lectures", default: none) [
      + #lecture.name
    ]
]


