#import "pre.typ": *

#show: my-config

#set page(
  "a4",
  width: auto,
  height: auto,
  flipped: true,
  margin: 1.5cm
)

#set text(lang: "de", region: "at")


// ============================================================================

#let my-box(x, color: gray, ..args) = box(
  fill: color.transparentize(50%),
  inset: 5pt,
  ..args
)[#x]

#let done(x, ..args) = my-box(color: green, ..args)[#x]
#let todo(x, ..args) = my-box(color: gray, ..args)[#x]
#let todo-light(x, ..args) = my-box(color: gray.lighten(50%), ..args)[#x]
#let fail(x, ..args) = my-box(color: red, ..args)[#x]
#let in_progress(x, ..args) = my-box(color: orange, ..args)[#x]


#let data = toml("main.toml")

#let include-in-progress = data.at("include_in_progress", default: false)

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

#let gg(x) = if x == () {
  (" ", todo)
} else if x.last() >= 5 {
  ("f", fail)
} else if x.last() < 5 and x.last() > 0 {
  ("x", done)
} else if x.last() == 0 {
  (" ", in_progress)
} else {
  (" ", todo)
}


#let ggg(k) = {
  let lecture = get-lecture-from-key(k)
    .values()
    .rev()
    .map(i => str(i))
    .join(" | ")
  
  let temp = range(4)
    .map(i => data.sem.at(i).at("course", default: ()))
    .flatten()
    .filter(i => k == i.code)

  let versuch = if temp == () {
    0
  } else {
    temp.last().at("versuch", default: 0)
  }
  
  let grades = temp.map(e => e.note)

  (gg(grades).last())(stroke: black, width: 99%)[  
    - [#gg(grades).first()] *#k* | #lecture \ versuch: #versuch ~ ~ note: #grades
  ]
}

#let get-grade-cp-name-from-lecture-key(k) = [#h(.25mm)] + todo(
  width: 50%,
  stroke: black,
)[ 
  #let block = k.split(".").first()
  #let lv = k.split(".").at(1)
  
  *#k* ~ #(
    x => {
      [#x.ects ECTS: ~ *#x.name*]
    }
  )(get-lecture-from-key(k))

  #let vls = if k.split(".").len() == 3 {
    (k.split(".").last(), )
  } else {
    data.at(block).at(lv).keys().filter(i => not i in ("name", "ects", "type", "versuch"))
  }

  #if vls == () {
    ggg(k)
  } else {
    stack(
      dir: ttb,
      for e in vls.map(x => ( (block, lv, x).join("."), x)) {
        ggg(e.first())
      }
    )
  }
]



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

#let ncs = {
  range(4)
  .map(i =>
    data
      .sem
      .at(i)
      .at("course", default: ())
      .map(e => e.note)
      .filter(e => e < 5 and e > 0)
  ).map(e =>  if e.len() == 0 {
      0
    } else {
      calc.round(
        e.sum(default: 0) / e.len(),
        digits: 4
      )
    }
  )
}

#let sem-ncs = {
  ([`I.`], [`II.`], [`III.`], [`IV.`])
    .zip(ncs)
    .map(x => x.first() + ": " + str(x.last()))
    .join([ #h(1mm) | #h(1mm) ])
}  

#let total-nc = (e =>  if e.len() == 0 { 0 } else { e.sum(default: 0) / e.len() } )( ncs.filter(e => e < 5 and e > 0) )


// ============================================================================

  
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
| #stack(dir: ltr, spacing: 1fr, [nc's: #h(1mm) #sem-ncs], text(weight: "bold")[#current-proc%], [nc: ~ #total-nc] )  | < | < | < | < | < | < | < | < |
    ]
  ]

]

*Vorlesungsverzeichnis*:
- *Uni Wien*: https://ufind.univie.ac.at/de/vvz_sub.html?path=325868
- *MedUni Wien*: https://campus.meduniwien.ac.at/med.campus/ee/ui/ca2/app/desktop/#/slc.tm.cp/student/courses
- *TU Wien*: todo ...

~

- https://vowi.fsinf.at/wiki/VorlesungsWiki
- https://vowi.fsinf.at/wiki/Curriculum:E066936
- https://vowi.fsinf.at/wiki/Curriculum:N066936



#set page(
  "a4",
  width: auto,
  height: 25cm,
  flipped: true,
  margin: 1.5cm,
)


= Pflicht- und Wahlmodule mit Lehrveranstaltungen

#shadowed[
Dieser Block wird erweitert durch eine Liste von Lehrveranstaltungen der Technischen Universität Wien,
die gleichwertig zu den oben gelisteten Modulen gewählt werden können. Dafür ist eine Mitbelegung
an der Technischen Universität notwendig. Die Liste wird jedes Studienjahr spätestens ein Monat vor
Beginn des Wintersemesters von der Curriculumdirektion öffentlich gemacht.
]

== A. Grundlagen 18 ECTS

#shadowed[
  #text(size: 13pt, weight: "bold", font: "Fira Code")[
    #important-box([
      +6cp extra aus block A als auflage \
      => 18 + 6 = 24 ects total
    ])
]
]

/*
#shadowed[
  #text(weight: "bold", size: 20pt, fill: red)[
    Note: +6cp extra aus block A als auflage
  ]
]
*/


Aus den folgenden Modulen sind drei Module zu wählen, die nicht bereits im Rahmen des
Bachelorstudiums der Informatik (Ausprägungsfach Medizininformatik) absolviert wurden. Im Zuge der
Gleichwertigkeitsprüfung nach §3 können bis zu zwei Module dieses Blocks vorgeschrieben werden.
Als Teil des Masterstudiums sind demnach die restlichen drei zu wählen


#stack(
  dir: ttb, spacing: 2mm,
  stack(
    dir: ltr, spacing: 2mm,
    get-grade-cp-name-from-lecture-key("A.A1"),
    get-grade-cp-name-from-lecture-key("A.A2"),
  ),
  stack(
    dir: ltr, spacing: 2mm,
    get-grade-cp-name-from-lecture-key("A.A3"),
    get-grade-cp-name-from-lecture-key("A.A4"),
  ),
  get-grade-cp-name-from-lecture-key("A.A5"),
)


#pagebreak()

== *B.* Kernfachkombination 24 ECTS

Eine *Kernfachkombination* (KfK) stellt im Hinblick auf eine Spezialisierung eine thematisch
abgestimmte *Kombination von Modulen* oder Lehrveranstaltungen *aus* den beiden Töpfen
*Anwendungsfächer* (die eine entsprechende Wissensgrundlage aus Medizin und Lebenswissenschaften
bieten; siehe *Abschnitt C*) und *Interdisziplinäre Informatik* (die die entsprechenden informatischen
Inhalte der Spezialisierung transportieren; siehe *Abschnitt D*) dar, *ergänzt durch* ein *Pflichtmodul
(Modul B1)* zur *Vertiefung in das Gebiet der Spezialisierung*. #text(fill: red)[*Es ist eine der fünf KfKs zu wählen.*]

=== Pflichtmodul Modul

#get-grade-cp-name-from-lecture-key("B.B1")

=== KfK fächer

#stack(
  dir: ltr, spacing: 5mm,
  stack(
    dir: ttb, spacing: 5mm,
    todo-light(stroke: black)[
      #text(fill: green.darken(40%), size: 15pt)[
        *KfK Bioinformatik:*
      ]
      
      #get-grade-cp-name-from-lecture-key("C.C4")
      #get-grade-cp-name-from-lecture-key("D.D2")
      #rect(stroke: 1mm)[
        #get-grade-cp-name-from-lecture-key("D.D5.a")
        #align(center)[*oder*]
        #get-grade-cp-name-from-lecture-key("D.D6.a")
      ]
    ],
    todo-light(stroke: black)[
      *KfK Neuroinformatik:*

      #get-grade-cp-name-from-lecture-key("C.C3")
      #get-grade-cp-name-from-lecture-key("D.D3")
      #rect(stroke: 1mm)[
        #get-grade-cp-name-from-lecture-key("D.D5.a")
        #align(center)[*oder*]
        #get-grade-cp-name-from-lecture-key("D.D6.b")
      ]
    ],
    todo-light(stroke: black)[
      *KfK Public Health Informatics:*

      #get-grade-cp-name-from-lecture-key("C.C2")
      #get-grade-cp-name-from-lecture-key("D.D4")
      #rect(stroke: 1mm)[
        #get-grade-cp-name-from-lecture-key("D.D12.b")
        #align(center)[*oder*]
        #get-grade-cp-name-from-lecture-key("D.D5.b")
      ]
    ],
  ),
  stack(
    dir: ttb, spacing: 5mm,
    
    todo-light(stroke: black)[
      *KfK Informatics for Assistive Technology:*

      #get-grade-cp-name-from-lecture-key("C.C6")
      #get-grade-cp-name-from-lecture-key("D.D8")
      #get-grade-cp-name-from-lecture-key("D.D11")
    ],
    todo-light(stroke: black)[
      *KfK Klinische Informatik:*
  
      #get-grade-cp-name-from-lecture-key("C.C5")
      #get-grade-cp-name-from-lecture-key("C.C6.b")
      #rect(stroke: 1mm)[
        #get-grade-cp-name-from-lecture-key("D.D5")
        #align(center)[*oder*]
        #get-grade-cp-name-from-lecture-key("D.D9")
      ]
      #get-grade-cp-name-from-lecture-key("D.D10")
    ]
  ),
 
)


#pagebreak()

== *C.* Anwendungsfach 12 ECTS

Dieser Block besteht aus einem *Pflichtmodul (Modul C1) und weiteren* Modulen, aus denen insgesamt *6
ECTS* auf Modul- oder Lehrveranstaltungsebene zu wählen sind. *Ausgenommen* davon *sind* die Module
oder Lehrveranstaltungen, *die der gewählten Kernfachkombination zugeordnet sind*.

=== Pflichtmodul:

#get-grade-cp-name-from-lecture-key("C.C1")


=== Wahlmodule:

#stack(
  dir: ltr, spacing: 2mm,
  stack(
    dir: ttb, spacing: 5mm,
      get-grade-cp-name-from-lecture-key("C.C2"),
      get-grade-cp-name-from-lecture-key("C.C4"),
  ),
  stack(
    dir: ttb, spacing: 5mm,
    get-grade-cp-name-from-lecture-key("C.C3"),
    get-grade-cp-name-from-lecture-key("C.C5"),
    get-grade-cp-name-from-lecture-key("C.C6"),
  ),
 
)


#pagebreak()



== *D.* Interdisziplinäre Informatik 24 ECTS

Dieser Block besteht aus einem *Pflichtmodul (Modul D1) und weiteren* Modulen, aus denen insgesamt
*15 ECTS* auf Modul- oder Lehrveranstaltungsebene zu wählen sind. *Ausgenommen* davon *sind die*
Module oder Lehrveranstaltungen, *die der gewählten Kernfachkombination zugeordnet sind*.

=== Pflichtmodul:

#get-grade-cp-name-from-lecture-key("D.D1")


=== Wahlmodule:

#stack(
  dir: ltr, spacing: 2mm,
  stack(
    dir: ttb, spacing: 5mm,
    get-grade-cp-name-from-lecture-key("D.D2"),
    get-grade-cp-name-from-lecture-key("D.D3"),
    get-grade-cp-name-from-lecture-key("D.D4"),
    get-grade-cp-name-from-lecture-key("D.D5"),
    get-grade-cp-name-from-lecture-key("D.D6"),
  ),
  stack(
    dir: ttb, spacing: 5mm,
    get-grade-cp-name-from-lecture-key("D.D8"),
    get-grade-cp-name-from-lecture-key("D.D9"),
    get-grade-cp-name-from-lecture-key("D.D10"),
    get-grade-cp-name-from-lecture-key("D.D11"),
    get-grade-cp-name-from-lecture-key("D.D12"),
  ),
  
)


#pagebreak()


== Freifächer 6 ECTS

Im Rahmen des Masterstudiums Medizinische Informatik sind Lehrveranstaltungen nach freier Wahl im
Umfang von 6 ECTS-Punkten zu absolvieren.

== Diplomand:innenseminare 6 ECTS

Im Rahmen des Masterstudiums Medizinische Informatik sind zwei Diplomand:innenseminare (je eines
im 3. und 4. Sem.) im Umfang von insgesamt 6 ECTS-Punkten zu absolvieren. Das erste Seminar dient
zur wissenschaftlichen Aufbereitung und Ausarbeitung eines speziellen Themas, mit dem Ziel, aus den
entsprechenden Erkenntnissen heraus das wissenschaftliche Thema der Masterarbeit zu entwickeln.
Das zweite Seminar dient zur wissenschaftlichen Vertiefung und Aufbereitung ausgewählter Fragen im
Kontext der Masterarbeit, mit dem Ziel, bei entsprechend hochwertigem Ergebnis diese Arbeiten zur
Präsentation im Rahmen einer wissenschaftlichen Konferenz aufzubereiten und einzureichen.

== Masterarbeit (4. Sem.) 30 ECTS

Auf die Masterarbeit sind die Bestimmungen der §§ 17a ff des II. Abschnitts der Satzung der
Medizinischen Universität Wien sinngemäß anzuwenden.
Die schriftliche Masterarbeit dient dem Nachweis der Befähigung, wissenschaftliche Themen
selbständig sowie inhaltlich und methodisch vertretbar zu bearbeiten. Die Aufgabenstellung der
schriftlichen Masterarbeit ist so zu wählen, dass für die Studierende oder den Studierenden die
Bearbeitung innerhalb von sechs Monaten möglich und zumutbar ist.
Das Thema der schriftlichen Masterarbeit ist aus einer der Kernfachkombinationen bzw. einem Modul
der Interdisziplinären Informatik zu entnehmen. Soll ein anderer Gegenstand gewählt werden oder
bestehen bezüglich der Zuordnung des gewählten Themas Unklarheiten, liegt die Entscheidung über
die Zulässigkeit beim zuständigen Organ.