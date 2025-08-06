#import "pre.typ": *

#show: my-config

#set page(
  "a4",
  width: auto,
  height: auto,
  flipped: true
)

#set text(lang: "de", region: "at")


#let include-in-progress = true


#let my-box(x, color: gray, ..args) = box(
  fill: color.transparentize(50%),
  inset: 5pt,
  ..args
)[#x]

#let done(x, ..args) = my-box(color: green, ..args)[#x]
#let todo(x, ..args) = my-box(color: gray, ..args)[#x]
#let fail(x, ..args) = my-box(color: red, ..args)[#x]
#let in_progress(x, ..args) = my-box(color: orange, ..args)[#x]


#let data = toml("main.toml")

#let get-lecture-from-key(key) = {
  key.split(".").fold(none, (acc, key) => {
    if acc == none {
      data.at(key, default: none)
    } else {
      acc.at(key, default: none)
    }
  })
}


#let get-name(key) = get-lecture-from-key(key).name
#let get-cp(key) = get-lecture-from-key(key).ects

#let format-name-and-cp(x) = {
  x.code + " " + str(get-cp(x.code)) +  "cp\n" +  get-name(x.code) + "\nn:" + str(x.note)
}

#let get-freifach-with-group(current-sem) = {
  current-sem
    .map(e => (e.code.split(".").first(), e))
    .filter(e => e.first() == "M")
    .map(e => (
      get-lecture-from-key(e.last().code).group,
      format-name-and-cp(e.last())
    ))
}

#let filter-for-group(c, xs) = {
  let temp = xs
    .map(e => (e.code.split(".").first(), e))
    .filter(e => e.first() == c)
    .map(e => format-name-and-cp(e.last())) + get-freifach-with-group(xs)
      .filter(x => x.first() == c)
      .map(e => e.last())

  if temp.len() == 0 {
    return ("-",)
  }

  temp
}


#let get-sem-results(x) = {
  // WARNING: IF YOU CALL SEM x=5 OR x=100 YOU WILL USE THE RESULT OF YOUR LAST SEM (iv) ...
  let x = calc.clamp(x, 0, 3)
  let current-sem = data.sem.at(x)

  let course = current-sem.at("course", default: none)
  if course == none {
    return (
    "A": ("-",),
    "B": ("-",),
    "C": ("-",),
    "D": ("-",),
    "F": ("-",),
    "DS": ("-",),
    "MA": ("-",),
    "nc": 0,
    "cp": 0,
    ) 
  }
    
  let kfk-bool-map = current-sem.course.map( (e) => { e.at("kfk", default: false) } )
  let temp = kfk-bool-map.zip(current-sem.course)
  let kfk-vls = temp.filter(e => e.first()).map(e => e.last())
  let normal-vls = temp.filter(x => not x.first()).map(e => e.last())

  (
    "A": filter-for-group("A", normal-vls),
    
    "B":  // b mit kfk
    kfk-vls.map(e =>
      format-name-and-cp(e)
    ) + filter-for-group("B", normal-vls),

    "C": filter-for-group("C", normal-vls),
    "D": filter-for-group("D", normal-vls),
    "F": filter-for-group("F", normal-vls),
    "DS": filter-for-group("DS", normal-vls),
    "MA": filter-for-group("MA", normal-vls),
    
    "nc": calc.round(
      eval(
        str(current-sem.course.map(e => { e.note }).sum())
        + " / "
        + str(current-sem.len())
      ),
      digits: 4
    ),

    "cp":
    current-sem.course
      .filter(e => e.note < 5 and (e.note > 0 or include-in-progress))
      .map(e => e.code)
      .map(e => get-lecture-from-key(e))
      .map(e => e.ects)
      .sum(default: 0)
  )
}

#let get-current-cp-for-block(block-char) = {
  range(4)
    .map(i => get-sem-results(i).at(block-char))
    .flatten()
    .map(x => {
      let code = x.split().first()
      let lecture = get-lecture-from-key(code)
      (code, if lecture != none { lecture.at("ects", default: 0) } else { 0 })
    })
    .dedup()
    .filter(pair =>
      pair.first()
      in
      // all valid lvs ( 0 < grade < 5 )
      range(4)
        .map(i => data.sem.at(i).at("course", default: ((note: 5),)))
        .flatten()
        .filter(e => e.note < 5 and (e.note > 0 or include-in-progress))
        .map(e => e.code)
        .dedup()
    )
    .map(pair => pair.last())
    .sum(default: 0)
}

// get the content of (x: current block, y: current semester) (for the table)
#let xy(c, sem-nr) = {
  get-sem-results(calc.clamp(sem-nr, 0, 3))
    .at(c)
    .map(e =>  if e.first() == "-" { "-" }
      else if int(e.last()) == 0 { in_progress(e, width: 45mm) }
      else if int(e.last()) < 5 { done(e, width: 45mm) }
      else { fail(e, width: 45mm) })
    .join("\n")
}

// macros for the table (shorter is better in the table)
#let g(x) = align(horizon)[#x]
#let ma = stack(dir: ltr, spacing: 3mm, [A. \ schriftlich \ 27cp], [B. \ Defensio \ 3cp])
#let p6 = text(weight: "bold", fill: red)[\ +6 auflage]


#let block-cp(block-char) = {
  let current = get-current-cp-for-block(block-char)
  let goal = if block-char == "F" { 6 } else { data.at(block-char).ects_required }
  
  [#current / #goal]
}

#let total = 120
#let current = range(4).map(i => get-sem-results(i).cp).sum()

#let current-proc = calc.round(
  eval(
    str(current)
    + " / "
    + str(total)
    + " * 100"
  ),
  digits: 3
)


#v(-20mm)
  
#align(center)[
  #text(size: 15pt)[*KfK Bioinformatik* ]
  #shadowed[  
    #tablem(ignore-second-row: false)[
| #align(center)[*Medizinische Informatik \ C U R R I C U L A ~ ~ ~ 30. Mitteilungsblatt ~ ~ ~ Nr. 33*] | < | < | < | < | < | < | < | < |
| sem. | *Pflicht- und Wahlmodulen* | < | < | < | #g[*Freifächer* \ (6 ECTS)] | #g[*Diplomanden- \ seminare* \ (6 ECTS)] | ~ *Masterarbeit* ~  | ECTS \ $ sum $ |
| ^ | A.\ Grundlagen \ 18cp #p6 | B.\ KfK \ 24cp | C.\ Angewant \ 12cp | D.\ Interdiszi. Inf. \ 24cp | ^ | ^ | #ma | ^ |
| *`I`*   | #xy("A", 0) | #xy("B", 0) | #xy("C", 0) | #xy("D", 0) | #xy("F", 0) | #xy("DS", 0) | #xy("MA", 0) |  #get-sem-results(0).cp cp |
| *`II`*  | #xy("A", 1) | #xy("B", 1) | #xy("C", 1) | #xy("D", 1) | #xy("F", 1) | #xy("DS", 1) | #xy("MA", 1) |  #get-sem-results(1).cp cp |
| *`III`* | #xy("A", 2) | #xy("B", 2) | #xy("C", 2) | #xy("D", 2) | #xy("F", 2) | #xy("DS", 2) | #xy("MA", 2) |  #get-sem-results(2).cp cp |
| *`IV`*  | #xy("A", 3) | #xy("B", 3) | #xy("C", 3) | #xy("D", 3) | #xy("F", 3) | #xy("DS", 3) | #xy("MA", 3) |  #get-sem-results(3).cp cp |
| $sum$   | #block-cp("A") | #block-cp("B") | #block-cp("C") | #block-cp("D") | #block-cp("F") | #block-cp("DS") | #block-cp("MA")  | #current / 120 #p6 |
|  #text(weight: "bold")[#current-proc%] | < | < | < | < | < | < | < | < |
    ]
  ]
]


#v(-20mm)


#set page(
  "a4",
  width: auto,
  flipped: true
)

