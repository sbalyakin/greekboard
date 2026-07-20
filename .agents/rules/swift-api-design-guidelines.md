# Swift API design (agent rules)

Condensed from [Apple's Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/). Apply when you **name, declare, or document** public or internal APIs. For architecture, concurrency, and project layout, follow `swift-code-guidelines.md` first.

## Core principle

**Clarity at the call site is the top goal.** A declaration is written once; call sites are read many times. When in doubt, write a realistic usage example and check that it reads naturally in English.

Clarity beats brevity. Compact code is fine, but do not sacrifice readable names for fewer characters.

If you cannot describe the API in one plain sentence, the design is probably wrong. Simplify before naming.

## When to apply

- Adding or renaming types, methods, properties, parameters, or protocols.
- Choosing argument labels and default parameters.
- Writing `///` documentation for non-obvious or public APIs.
- Reviewing whether a name matches Swift standard library style.

Skip heavy documentation for obvious private helpers. Match surrounding project names (`*Protocol`, `Mac*Adapter`) even when Apple guidelines suggest a different suffix.

## Naming



### Call-site clarity

- Include every word needed to remove ambiguity at the use site.
  - Good: `employees.remove(at: x)` — removes by index.
  - Bad: `employees.remove(x)` — could mean remove the element equal to `x`.
- Omit words that only repeat type information.
  - Bad: `removeElement(_ member: Element)`
  - Good: `remove(_ member: Element)`
- Name parameters by **role**, not by type constraint.
  - Bad: `restock(from widgetFactory: WidgetFactory)`
  - Good: `restock(from supplier: WidgetFactory)`
- When a type name is weak (`NSObject`, `Any`, `String`, `Int`), add a role noun before the parameter.
  - Bad: `add(_ observer: NSObject, for keyPath: String)`
  - Good: `addObserver(_ observer: NSObject, forKeyPath path: String)`



### Fluent English at the call site

- Method names should form grammatical phrases at the call site.
  - Good: `x.insert(y, at: z)`, `x.subviews(havingColor: y)`
  - Bad: `x.insert(y, position: z)`, `x.subviews(color: y)`
- Factory methods start with `make`: `x.makeIterator()`.
- Initializers and factories: the **first argument must not** continue the base name as a phrase.
  - Good: `Color(red: 32, green: 64, blue: 128)`, `Link(target: destination)`
  - Bad: `Color(havingRGBValuesRed: 32, green: 64, andBlue: 128)`
- Exception: value-preserving type conversions omit the first label: `Int64(someUInt32)`.



### Side effects and parts of speech


| Kind                         | Name as                                                   |
| ---------------------------- | --------------------------------------------------------- |
| Nonmutating, no side effects | Noun phrase: `distance(to:)`, `successor()`               |
| Mutating or side effects     | Imperative verb: `sort()`, `append(_:)`                   |
| Boolean property or method   | Assertion about receiver: `isEmpty`, `intersects(_:)`     |
| Type or stored property      | Noun: `first`, `count`                                    |
| Protocol for "what it is"    | Noun: `Collection`                                        |
| Protocol for capability      | `able` / `ible` / `ing`: `Equatable`, `ProgressReporting` |




### Mutating / nonmutating pairs

Name pairs consistently:


| Mutating          | Nonmutating           |
| ----------------- | --------------------- |
| `reverse()`       | `reversed()`          |
| `append(y)`       | `appending(y)`        |
| `stripNewlines()` | `strippingNewlines()` |
| `formUnion(z)`    | `union(z)`            |


- Verb-based ops: imperative for mutating; past participle (`-ed`) or present participle (`-ing`) for nonmutating.
- Noun-based ops: noun for nonmutating; `form` + noun for mutating (`formUnion`, `formSuccessor`).



### Terminology

- Prefer common words over jargon when meaning stays clear.
- If you use a term of art, use its established meaning. Do not invent a new one.
- Avoid non-standard abbreviations. Standard domain abbreviations (`UTF8`, `sin`) are fine.
- Prefer precedented Swift/stdlib names (`Array`, `contains`) over invented synonyms (`List`, `hasItem`).



### Case and overloads

- Types and protocols: `UpperCamelCase`. Everything else: `lowerCamelCase`.
- Acronyms in American English: match case style (`utf8Bytes`, `isRepresentableAsASCII`, not `UTF8Bytes`).
- Reuse the same method name only when semantics truly match across overloads.
- Do not overload on return type alone; it breaks type inference.



## Argument labels

Default pattern:

```swift
func move(from start: Point, to end: Point)
x.move(from: a, to: b)
```

Rules:

1. **Value-preserving conversions**: no first label. `Int64(x)`, `String(veryLargeNumber, radix: 16)`.
2. **Narrowing conversions**: label describes the narrowing. `init(truncating:)`, `init(saturating:)`.
3. **First argument is a prepositional phrase**: label starts at the preposition. `removeBoxes(havingLength: 12)`.
4. **First argument completes a grammatical phrase with the base name**: omit the label. `addSubview(y)`.
5. **Otherwise**: label the first argument. `dismiss(animated:)`, `split(maxSplits:)`.
6. **All remaining arguments**: always labeled.
7. **Parameters with defaults**: always labeled (they may be omitted at the call site).

When two arguments are one abstraction (`x` and `y` of a point), put the label after the preposition: `moveTo(x:y:)`, not `move(toX:y:)`.

## Parameters and methods

- Parameter names exist for documentation even when omitted at the call site. Pick names that make `///` text read naturally.
- Prefer default parameters over method families (`compare(_:options:range:locale:)` vs four overloads).
- Put defaulted parameters at the end.
- Prefer methods and properties on a type over free functions, except when there is no `self`, the API is unconstrained generic (`print`), or function syntax is domain standard (`sin`).
- Document non-O(1) computed properties; callers assume properties are cheap.
- Label tuple members and closure parameters in public API signatures.
- With unconstrained polymorphism (`Any`, unconstrained generics), avoid ambiguous overload sets. Prefer explicit names like `append(contentsOf:)` over a second `append(_:)`.

Production APIs that capture file location: prefer `#fileID` over `#filePath` or `#file`.

## Documentation (`///`)

Write for the reader at the call site, not for the author.

- One-line summary first. Often enough on its own.
- Summary style: sentence fragment, period at end. State what the symbol **does** or **is**; skip `Void` and null effects.
  - Function: what it does and returns.
  - Subscript: what it accesses.
  - Initializer: what it creates.
  - Property or type: what it is.
- Add `Parameter`, `Returns`, `Throws`, `Note`, `Precondition` only when the summary is not enough.
- Do not restate the type name in the summary.
- Do not document obvious code.

Example:

```swift
/// Returns the elements of `self` that satisfy `predicate`.
func filter(_ predicate: (Element) -> Bool) -> [Element]

/// Inserts `newHead` at the beginning of `self`.
mutating func prepend(_ newHead: Element)
```



## Anti-patterns (do not introduce)


| Bad                                                   | Why                            | Prefer                   |
| ----------------------------------------------------- | ------------------------------ | ------------------------ |
| `remove(x)` for index removal                         | Ambiguous at call site         | `remove(at: x)`          |
| `removeElement(_:)`                                   | Redundant type word            | `remove(_:)`             |
| `Manager`, `Helper`, `Utils`                          | Vague role                     | Name by responsibility   |
| `foo(_:)` + `foo(_:)` on `Any`                        | Ambiguous overload             | `foo(contentsOf:)`       |
| Two `value()` overloads differing only by return type | Inference breaks               | Distinct names           |
| `index()` and `index(_:inTable:)`                     | Same name, different semantics | Rename one               |
| Forced grammatical labels on first init arg           | `Color(havingRed:...)`         | `Color(red:green:blue:)` |




## Before finishing API changes

API naming and documentation only. For build, layering, access control, and tests, use the pre-finish checklist in `swift-code-guidelines.md`.

1. Read the call site aloud. Does it sound like natural English?
2. Is every parameter role clear without reading the declaration?
3. Do mutating/nonmutating pairs follow `sort`/`sorted` or `formUnion`/`union` patterns?
4. Are argument labels correct for conversions, prepositions, and defaulted params?
5. Is `///` limited to non-obvious behavior and written as a summary, not a type echo?
6. Do new names match project patterns (`*Protocol`, `Mac*Adapter`) and stdlib conventions?

