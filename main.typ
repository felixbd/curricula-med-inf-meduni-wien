#import "@preview/cheq:0.2.2": checklist
#import "@preview/tablem:0.2.0": tablem, three-line-table

#let flag = not true

#set page(fill: if flag { gray.darken(35%) } else { white } )

// #set text(font: "Fira Sans")
// #show heading: set text(font: "Libre Baskerville")

#set par(justify: true)

#show: checklist.with(
  marker-map: (
    " ": sym.ballot,
    "x": sym.ballot.cross,
    "-": sym.bar.h,
    "/": sym.slash.double
  )
)

#set page(
  // "a2", flipped: true,
  width: auto, height: auto,
  margin: 1.5cm
)

#set text(lang: "de", region: "at")

#let my-box(x, color: gray, ..args) = box(
  fill: color.transparentize(50%),
  inset: 5pt,
  radius: 2mm,
  stroke: .2mm,
  ..args
)[#x]


#let done(x, ..args) = my-box(color: green, ..args)[#x]
#let todo(x, ..args) = my-box(color: gray, ..args)[#x]
#let todo-light(x, ..args) = my-box(color: gray.lighten(50%), ..args)[#x]
#let fail(x, ..args) = my-box(color: red.transparentize(25%), ..args)[#x]
#let in_progress(x, ..args) = my-box(color: orange, ..args)[#x]


// === LOAD DATA ============================================================


#let data = toml("main.toml")

#let include-failed = data.at("include_failed", default: false)
#let include-in-progress = data.at("include_in_progress", default: true)

#let auflagen-ects = text(weight: "bold", fill: red)[+6 auflage]

#let data = {
  let sem = data.remove("sem")

  data.insert(
    "sem",
    sem.map(entry => {
      entry.insert(
        "course",
        entry.at("course", default: ())
          .filter(c =>
            (include-in-progress or c.note != 0) and
            (include-failed or c.note < 5)
          )
      )
      entry
    })
  )

  data
}

#let range-of-sems = range(data.sem.len())
#let sem-courses = range-of-sems.map(i => data.sem.at(i).at("course", default: ()))
#let all-courses = sem-courses.flatten()
#let valid-course-codes = {
  all-courses
    .filter(e => e.note < 5 and (e.note > 0 or include-in-progress))
    .map(e => e.code)
    .dedup()
}

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
#let get-course-cp(course) = {
  let lecture = get-lecture-from-key(course.code)
  if lecture == none { 0 } else { lecture.at("ects", default: 0) }
}

#let format-name-and-cp(x) = {
  x.code + " " + str(
    get-cp(x.code)
  ) + "cp" + if x.at("ps", default: false) {
    "\n!! projekt stud. !!"
  } + "\n" +  get-name(x.code) + "\ngrade: " + str(x.note)
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

#let get-grade-status(x) = if x == () {
  (" ", todo)
} else if x.last() >= 5 {
  ("f", fail)
} else if x.last() < 5 and x.last() > 0 {
  ("x", done)
} else if x.last() == 0 {
  (" ", in_progress)
} else {
  ("/", todo)
}


#let format-lecture-grade-info(k) = {
  let lecture = get-lecture-from-key(k)
    .values()
    .rev()
    .map(i => str(i))
    .join(" | ")
  
  let temp = all-courses
    .filter(i => k == i.code)

  let versuch = if temp == () {
    0
  } else {
    temp.last().at("versuch", default: 0)
  }
  
  let grades = temp.map(e => e.note)

  (get-grade-status(grades).last())(stroke: black, width: 99%)[
    - [#get-grade-status(grades).first()] *#k* | #lecture
     \ versuch: *#versuch* ~ ~ note:
     *#grades.map(e => str(e)).join([~ $->$ ~])*
  ]
}

#let get-grade-cp-name-from-lecture-key(k, width: 50%) = [ #h(.25mm) ] + todo(
  width: width,
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
    data.at(block).at(lv).keys().filter(i =>
      not i in ("name", "ects", "type", "versuch")
    )
  }

  #if vls == () {
    format-lecture-grade-info(k)
  } else {
    stack(
      dir: ttb,
      for e in vls.map(x => ( (block, lv, x).join("."), x)) {
        format-lecture-grade-info(e.first())
      }
    )
  }
]



#let get-sem-results(x) = {
  let x = calc.clamp(x, 0, data.sem.len() - 1)
  let current-sem = data.sem.at(x, default: (:))
  let course = current-sem.at("course", default: ())

  if course == () {
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
    "cp-passed": 0,
    ) 
  }
    
  let temp = course
    .map(e =>  e.at("kfk", default: false))
    .zip(course)
    
  let kfk-vls = temp.filter(e => e.first()).map(e => e.last())

  let frei-zip = course
    .map(e => e.at("frei", default: false))
    .zip(course)
    
  let frei-vls = frei-zip.filter(e => e.first()).map(e => e.last())
  
  let normal-vls = course
    .filter(x =>
      not x.at("frei", default: false) and
      not x.at("kfk", default: false)
    )
  
  (
    "A": filter-for-group("A", normal-vls),
    
    "B":  // b mit kfk
    kfk-vls.map(e =>
      format-name-and-cp(e)
    ) + filter-for-group("B", normal-vls),

    "C": filter-for-group("C", normal-vls),
    "D": filter-for-group("D", normal-vls),
    
    "F": frei-vls.map(e =>
      format-name-and-cp(e)
    ) + filter-for-group("F", normal-vls),
    
    "DS": filter-for-group("DS", normal-vls),
    "MA": filter-for-group("MA", normal-vls),
    
    "nc": if course.len() == 0 { 0 } else {
      calc.round(
        course.map(e => e.note).sum(default: 0) / course.len(),
        digits: 4
      )
    },

    "cp":
    course
      .filter(e => e.note < 5 and (e.note > 0 or include-in-progress))
      .map(get-course-cp)
      .sum(default: 0),
    
    "cp-passed":
    course
      .filter(e => e.note < 5 and e.note > 0)
      .map(get-course-cp)
      .sum(default: 0)
  )
}

#let sem-results = range-of-sems.map(get-sem-results)
#let get-sem-result(i) = sem-results.at(calc.clamp(i, 0, data.sem.len() - 1))

#let get-current-cp-for-block(block-char) = {
  sem-results
    .map(sem => sem.at(block-char))
    .flatten()
    .map(x => {
      let code = x.split().first()
      let lecture = get-lecture-from-key(code)
      (code, if lecture != none { lecture.at("ects", default: 0) } else { 0 })
    })
    .dedup()
    .filter(pair =>
      pair.first()
      in valid-course-codes
    )
    .map(pair => pair.last())
    .sum(default: 0)
}

// (current block, current semester) 
#let get-table-cell-content(c, sem-nr) = {
  get-sem-result(sem-nr)
    .at(c)
    .map(e =>  if e.first() == "-" { "-" } else {
      let grade = float(e.split("grade: ").last())
      if grade == 0 { in_progress(e, width: 45mm) }
      else if grade < 5 { done(e, width: 45mm) }
      else { fail(e, width: 45mm) }
    })
    .join("\n")
}


#let block-cp(block-char) = {
  let current = get-current-cp-for-block(block-char)
  let goal = if block-char == "F" { 6 } else { data.at(block-char).ects_required }
  
  [#current / #goal]
}

#let total = 126  // 120 + 6cp auflage
#let current = sem-results.map(e => e.cp).sum()

#let current-proc = calc.round(
  eval(
    str(current)
    + " / "
    + str(total)
    + " * 100"
  ),
  digits: 3
)

#let current-passed = sem-results.map(e => e.cp-passed).sum()

#let current-passed-proc = calc.round(
  eval(
    str(current-passed)
    + " / "
    + str(total)
    + " * 100"
  ),
  digits: 3
)

#let passed-courses = all-courses.filter(e => e.note < 5 and e.note > 0)
#let passed-course-codes = passed-courses.map(e => e.code).dedup()

#let has-passed(key) = passed-course-codes.filter(code => code == key or code.starts-with(key + ".")).len() > 0
#let count-passed(keys) = keys.filter(has-passed).len()
#let has-any-passed(keys) = keys.filter(has-passed).len() > 0

#let kfk-progress(required, one-of-groups: ()) = {
  let done = count-passed(required) + one-of-groups
    .map(group => if has-any-passed(group) { 1 } else { 0 })
    .sum(default: 0)
  let total = required.len() + one-of-groups.len()
  (done: done, total: total)
}

#let get-block-cp(block-char, passed-only: false) = {
  let source = if passed-only { passed-courses } else { all-courses }
  let selected = source.filter(course => {
    let prefix = course.code.split(".").first()
    if block-char == "B" {
      prefix == "B" or course.at("kfk", default: false)
    } else if block-char == "F" {
      course.at("frei", default: false) or (
        prefix == "M" and
        get-lecture-from-key(course.code).at("group", default: "") == "F"
      )
    } else {
      prefix == block-char and not course.at("kfk", default: false)
    }
  })

  selected
    .map(e => e.code)
    .dedup()
    .map(code => get-lecture-from-key(code).at("ects", default: 0))
    .sum(default: 0)
}

#let block-progress(block-char) = (
  done: get-block-cp(block-char, passed-only: true),
  total: if block-char == "F" { 6 } else { data.at(block-char).ects_required }
)

#let progress-label(done, total) = [#done/#total]
#let progress-state(done, total) = if done >= total {
  "DONE"
} else if done > 0 {
  "IN-PROGRESS"
} else {
  "TODO"
}
#let progress-color(done, total) = if done >= total {
  green
} else if done > 0 {
  orange
} else {
  red
}

#let traffic-light(done, total) = circle(
  radius: 3.5mm,
  fill: progress-color(done, total).lighten(10%),
  stroke: .35pt + black
)

#let kfk-bio = kfk-progress(
  ("C.C4", "D.D2"),
  one-of-groups: (("D.D5.a", "D.D6.a"),)
)
#let kfk-neuro = kfk-progress(
  ("C.C3", "D.D3"),
  one-of-groups: (("D.D5.a", "D.D6.b"),)
)
#let kfk-public-health = kfk-progress(
  ("C.C2", "D.D4"),
  one-of-groups: (("D.D12.b", "D.D5.b"),)
)
#let kfk-assistive = kfk-progress(("C.C6", "D.D8", "D.D11"))
#let kfk-klinisch = kfk-progress(
  ("C.C5", "C.C6.b", "D.D10"),
  one-of-groups: (("D.D5", "D.D9"),)
)


#let ncs = {
  sem-courses
    .map(courses => courses.map(e => e.note).filter(e => e < 5 and e > 0))
    .map(e =>  if e.len() == 0 {
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
  range-of-sems.map(e => raw(numbering("I", e + 1)))
    .zip(ncs)
    .map(x => x.first() + ": " + str(x.last()))
    .join([ #h(1mm) | #h(1mm) ])
} 


#let total-nc = calc.round(
  (e =>  if e.len() == 0 { 0 } else { e.sum(default: 0) / e.len() } )(
    ncs.filter(e => e < 5 and e > 0)
  ),
  digits: 4
)


#let cps(i) = {
  str(
    sem-results.slice(0, i).map(e => e.cp).sum(default: 0)
  )
}


// ======================================================================

~ ~ #datetime.today().display("[day]. [month repr:short] [year]")
#h(25cm)
https://github.com/felixbd/curricula-med-inf-meduni-wien

#show table.cell.where(x: 0): strong


#block(
  stroke: 2pt + black,
  radius: 10pt,
  table(
    columns: (auto, ) * 10,
    align: center,
    stroke: (x, y) => (
      top: if y > 0 { black },
      left: if x > 0 { black }
    ),
    table.header(
      table.cell(colspan: 10)[
        #set align(center)
        #set text(size: 15pt)
        ~ \ *Medizinische Informatik \
        C U R R I C U L A ~ ~ ~ 30. Mitteilungsblatt ~ ~ ~ Nr. 33* \ ~
      ],
      
      table.cell(rowspan: 2)[ #rotate(90deg, reflow: true)[Semester] ],
      table.cell(colspan: 4)[ *Pflicht- und Wahlmodulen* ],
      table.cell(rowspan: 2)[
        #set align(horizon)
        *Freifächer* \ (6 ECTS)
      ],
      table.cell(rowspan: 2)[
        #set align(horizon)
        *Diplomanden- \ seminare* \ (6 ECTS)
      ],
      [ ~ *Masterarbeit* ~ ],
      table.cell(rowspan: 2)[ ECTS \ $ sum $ ],
      table.cell(rowspan: 2)[ #rotate(90deg, reflow: true)[number of \ scheduled \ lectures]],
      [Block A.\ *Grundlagen* \ 18cp ~ #auflagen-ects ],
      [Block B.\ *KfK* \ 24cp ],
      [Block C.\ *Angewant* \ 12cp ],
      [Block D.\ *Interdiszi. Inf.* \ 24cp ],
      stack(dir: ltr, spacing: 6mm, [schriftlich \ 27cp], [ \ Defensio \ 3cp])
    ),
    table.hline(stroke: 1.5pt + black, start: 1, end: 8),
    // table.vline(start: 1, end: 5, stroke: 3pt + black),
    ..for (sem_nr, sem_courses) in data.sem.enumerate() {
      (
        [
          *#{ raw(numbering("I" , sem_nr + 1)) }*
          #rotate(90deg, reflow: true)[
            #data.sem.at(sem_nr).at("beschreibung", default: "")
          ]
        ],
        ..("A", "B", "C", "D", "F", "DS", "MA").map(e => get-table-cell-content(e, sem_nr)),
        [
          #v(5mm)
          this sem.
          
          #get-sem-result(sem_nr).cp 
          
          #v(1fr)

          $sum$ #cps(sem_nr + 1)
          #v(5mm)
        ],
        [
          #set align(center + horizon)
          #sem_courses.course.len()

          ~

          #rotate(90deg, reflow: true)[
            $ (sum "ects") / (sum "lva") = #eval(
              str( get-sem-result(sem_nr).cp ) +
              " / " + 
              str( sem_courses.course.len() )
              )
            $
          ]
        ]
      )    
    },
    table.hline(stroke: 1.5pt + black, start: 1, end: 8),

    table.footer(
      [ $sum$ ],
      [ #block-cp("A") #text(fill: red)[*+6*] $=>$ 24],
      ..("B", "C", "D", "F", "DS", "MA").map(e => block-cp(e)),
      [#current / 120 \ #auflagen-ects],
      [  ],
      [],
      table.cell(colspan: 8, stroke: (left: none, right: none),
        stack(
          dir: ltr,spacing: 1fr,
          [~ nc's: #h(1mm) | #sem-ncs |],
          text(weight: "bold")[scheduled: #current-proc%],
          text(weight: "bold")[passed: #current-passed-proc%],
          text(weight: "bold")[todo: #{
            calc.round(current-proc - current-passed-proc, digits: 4)
          }%],
          [nc: ~ #total-nc ~]
        )
        
      ), table.cell(stroke: (left: none))[]
    )
  )
)


#stack(
  dir: ltr, spacing: .5cm,
  box(fill: orange.lighten(20%).transparentize(10%), inset: 2mm, radius: 2mm)[in Progress (grade: 0)],
  box(fill: green.lighten(20%).transparentize(10%), inset: 2mm, radius: 2mm)[done (grade: >= 1 and <= 4)],
  box(fill: red.lighten(20%).transparentize(10%), inset: 2mm, radius: 2mm)[droped / failed / redo (grade: >= 5)],
)



#pagebreak(weak: true)

= TODOs:

#place(top + right)[
  #datetime.today().display("[day]. [month repr:short] [year]")
]


~

#grid(
  columns: (auto,) * 3,
  gutter: 2mm,
  
  ..data.sem.map(
    e => e.course
  ).flatten().filter(
    e => e.note == 0
  ).map(
    e => (
      {
        let (day, month, year) = e.at("date", default: "01.12.2026").split(".").map(int)
        datetime(day: day, month: month, year: year)
      }, 
      rect(get-lecture-from-key(e.code).name)
    )
  ).sorted(key: it => it.first(), by: (l, r) => r >= l).map(
    it => (
      rect(it.at(0).display("[day]. [month repr:short] [year]")),
      str(repr(it.at(0) - datetime.today())).replace("duration", ""),
      it.at(1)
    )
  ).flatten()
)

#pagebreak(weak: true)

= Schnellübersicht Studienfortschritt

#let block-a = block-progress("A")
#let block-b = block-progress("B")
#let block-c = block-progress("C")
#let block-d = block-progress("D")
#let block-f = block-progress("F")
#let block-ds = block-progress("DS")
#let block-ma = block-progress("MA")

#table(
  columns: (7cm, 2.2cm, 3cm, 2cm),
  align: (left, center, center, center),
  stroke: .3pt + black,
  table.header(
    [*Bereich*],
    [*Status*],
    [*Fortschritt*],
    [*Ampel*],
  ),
  [Block A – Grundlagen], [#progress-state(block-a.done, block-a.total)], [#progress-label(block-a.done, block-a.total)], [#traffic-light(block-a.done, block-a.total)],
  [Block B – Kernfachkombination], [#progress-state(block-b.done, block-b.total)], [#progress-label(block-b.done, block-b.total)], [#traffic-light(block-b.done, block-b.total)],
  [Block C – Anwendungsfach], [#progress-state(block-c.done, block-c.total)], [#progress-label(block-c.done, block-c.total)], [#traffic-light(block-c.done, block-c.total)],
  [Block D – Interdisziplinäre Informatik], [#progress-state(block-d.done, block-d.total)], [#progress-label(block-d.done, block-d.total)], [#traffic-light(block-d.done, block-d.total)],
  [Freifächer], [#progress-state(block-f.done, block-f.total)], [#progress-label(block-f.done, block-f.total)], [#traffic-light(block-f.done, block-f.total)],
  [Diplomand:innenseminare], [#progress-state(block-ds.done, block-ds.total)], [#progress-label(block-ds.done, block-ds.total)], [#traffic-light(block-ds.done, block-ds.total)],
  [Masterarbeit], [#progress-state(block-ma.done, block-ma.total)], [#progress-label(block-ma.done, block-ma.total)], [#traffic-light(block-ma.done, block-ma.total)],
)

#v(6mm)

#table(
  columns: (7cm, 3cm, 2.2cm),
  align: (left, center, center),
  stroke: .3pt + black,
  table.header(
    [*KfK*],
    [*Done/Total*],
    [*Ampel*],
  ),
  [Bioinformatik], [#progress-label(kfk-bio.done, kfk-bio.total)], [#traffic-light(kfk-bio.done, kfk-bio.total)],
  [Neuroinformatik], [#progress-label(kfk-neuro.done, kfk-neuro.total)], [#traffic-light(kfk-neuro.done, kfk-neuro.total)],
  [Public Health Informatics], [#progress-label(kfk-public-health.done, kfk-public-health.total)], [#traffic-light(kfk-public-health.done, kfk-public-health.total)],
  [Informatics for Assistive Technology], [#progress-label(kfk-assistive.done, kfk-assistive.total)], [#traffic-light(kfk-assistive.done, kfk-assistive.total)],
  [Klinische Informatik], [#progress-label(kfk-klinisch.done, kfk-klinisch.total)], [#traffic-light(kfk-klinisch.done, kfk-klinisch.total)],
)

#v(2mm)
#text(size: 9pt)[Ampel: grün = fertig, orange = teilweise erledigt, rot = noch offen.]





#set page(
  // "a4",
  width: 25cm,
  height: auto,
  // flipped: true,
  margin: 1.5cm,
)

= Pflicht- und Wahlmodule mit Lehrveranstaltungen

Dieser Block wird erweitert durch eine Liste von Lehrveranstaltungen der Technischen Universität Wien,
die gleichwertig zu den oben gelisteten Modulen gewählt werden können. Dafür ist eine Mitbelegung
an der Technischen Universität notwendig. Die Liste wird jedes Studienjahr spätestens ein Monat vor
Beginn des Wintersemesters von der Curriculumdirektion öffentlich gemacht.


== A. Grundlagen 18 ECTS

#let callout(accent: red, body) = block(
  width: 50%, inset: (x: 11pt, y: 9pt), radius: 3pt,
  fill: accent.lighten(88%),
  stroke: (left: 3pt + accent
    /*(
      paint: red, // gradient.linear(..color.map.crest),
      thickness: 5pt, dash: "dashed", // cap: "round",
    )*/
  ),
)[
  #set par(first-line-indent: 0em)
  // #emoji.siren #emoji.explosion #emoji.excl
  #text(weight: "extrabold", 15pt)[Note:]
  #body
]


#text(size: 13pt, weight: "bold")[ //, font: "Fira Code")[
  #callout([
    #auflagen-ects extra aus Block A \
    => 18 + 6 = 24 ects total
  ])
]


Aus den folgenden Modulen *sind drei Module zu wählen*, die nicht bereits im Rahmen des
Bachelorstudiums der Informatik (Ausprägungsfach Medizininformatik) absolviert wurden. Im Zuge der
*Gleichwertigkeitsprüfung* nach §3 *können bis zu zwei Module* dieses Blocks *vorgeschrieben* werden.
Als Teil des Masterstudiums sind demnach die restlichen drei zu wählen


#stack(
  dir: ttb, spacing: 3mm,
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


  
  stack(
    dir: ltr, spacing: 2cm,
    get-grade-cp-name-from-lecture-key("A.A5"),
    three-line-table()[
      | total ects     |
      | -------------- |
      | #block-cp("A") (+ 6 auflage) |
    ]
  ),
)


#pagebreak(weak: true)


== *B.* Kernfachkombination 24 ECTS

Eine *Kernfachkombination* (KfK) stellt im Hinblick auf eine Spezialisierung eine thematisch
abgestimmte *Kombination von Modulen* oder Lehrveranstaltungen *aus* den beiden Töpfen
*Anwendungsfächer* (die eine entsprechende Wissensgrundlage aus Medizin und Lebenswissenschaften
bieten; siehe *Abschnitt C*) und *Interdisziplinäre Informatik* (die die entsprechenden informatischen
Inhalte der Spezialisierung transportieren; siehe *Abschnitt D*) dar, *ergänzt durch* ein *Pflichtmodul
(Modul B1)* zur *Vertiefung in das Gebiet der Spezialisierung*. #text(fill: red)[*Es ist eine der fünf KfKs zu wählen.*]

=== Pflichtmodul Modul


#stack(
  dir: ltr, spacing: 2cm,
  get-grade-cp-name-from-lecture-key("B.B1"),
  three-line-table()[
    | total ects     |
    | -------------- |
    | #block-cp("B") |
  ]
)


=== KfK fächer

#stack(
  dir: ltr, spacing: 7mm,
  stack(
    dir: ttb, spacing: 7mm,
    todo-light(
      stroke: (
        paint: gradient.linear(..color.map.crest),
        thickness: 2pt, dash: "dashed", cap: "round")
    )[
        *KfK Bioinformatik* #progress-label(kfk-bio.done, kfk-bio.total):

      #get-grade-cp-name-from-lecture-key("C.C4")
      #get-grade-cp-name-from-lecture-key("D.D2")
      #rect(stroke: 1mm, radius: 2mm)[
        #get-grade-cp-name-from-lecture-key("D.D5.a")
        #align(center)[*oder*]
        #get-grade-cp-name-from-lecture-key("D.D6.a")
      ]
    ],
    todo-light(stroke: black)[
      *KfK Neuroinformatik* #progress-label(kfk-neuro.done, kfk-neuro.total):

      #get-grade-cp-name-from-lecture-key("C.C3")
      #get-grade-cp-name-from-lecture-key("D.D3")
      #rect(stroke: 1mm, radius: 2mm)[
        #get-grade-cp-name-from-lecture-key("D.D5.a")
        #align(center)[*oder*]
        #get-grade-cp-name-from-lecture-key("D.D6.b")
      ]
    ],
    todo-light(stroke: black)[
      *KfK Public Health Informatics* #progress-label(kfk-public-health.done, kfk-public-health.total):

      #get-grade-cp-name-from-lecture-key("C.C2")
      #get-grade-cp-name-from-lecture-key("D.D4")
      #rect(stroke: 1mm, radius: 2mm)[
        #get-grade-cp-name-from-lecture-key("D.D12.b")
        #align(center)[*oder*]
        #get-grade-cp-name-from-lecture-key("D.D5.b")
      ]
    ],
  ),
  stack(
    dir: ttb, spacing: 5mm,
    
    todo-light(stroke: black)[
      *KfK Informatics for Assistive Technology* #progress-label(kfk-assistive.done, kfk-assistive.total):

      #get-grade-cp-name-from-lecture-key("C.C6")
      #get-grade-cp-name-from-lecture-key("D.D8")
      #get-grade-cp-name-from-lecture-key("D.D11")
    ],
    todo-light(stroke: black)[
      *KfK Klinische Informatik* #progress-label(kfk-klinisch.done, kfk-klinisch.total):
  
      #get-grade-cp-name-from-lecture-key("C.C5")
      #get-grade-cp-name-from-lecture-key("C.C6.b")
      #rect(stroke: 1mm, radius: 2mm)[
        #get-grade-cp-name-from-lecture-key("D.D5")
        #align(center)[*oder*]
        #get-grade-cp-name-from-lecture-key("D.D9")
      ]
      #get-grade-cp-name-from-lecture-key("D.D10")
    ]
  ),
 
)


#pagebreak(weak: true)

== *C.* Anwendungsfach 12 ECTS

Dieser Block besteht aus einem *Pflichtmodul (Modul C1) und weiteren* Modulen, aus denen insgesamt *6
ECTS* auf Modul- oder Lehrveranstaltungsebene zu wählen sind. *Ausgenommen* davon *sind* die Module
oder Lehrveranstaltungen, *die der gewählten Kernfachkombination zugeordnet sind*.

=== Pflichtmodul:



#stack(
  dir: ltr, spacing: 2cm,
  get-grade-cp-name-from-lecture-key("C.C1"),
  three-line-table()[
    | total ects     |
    | -------------- |
    | #block-cp("C") |
  ]
)



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


#stack(
  dir: ltr, spacing: 2cm,
  get-grade-cp-name-from-lecture-key("D.D1"),
  three-line-table()[
    | total ects     |
    | -------------- |
    | #block-cp("D") |
  ]
)


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
