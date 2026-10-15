# MapKitSwiftSearch

Location search for apps: suggest places as a user types, then resolve the one they choose.

## Language

**Query fragment**:
The partial text a user has typed so far, searched for completions on every change.
_Avoid_: search term, query string, input

**Completion**:
One suggested place for a query fragment, with a title, a subtitle, and the highlights that match the fragment.
_Avoid_: suggestion, result, autocomplete

**Highlight**:
A part of a completion's title or subtitle that matches a word of the query fragment. A completion can have several.
_Avoid_: match range

**Superseded search**:
A search whose query fragment was replaced by a newer one before it returned. It produces no completions.
_Avoid_: debounced search, duplicate search

**Placemark**:
A resolved place, with coordinate, name, and address, for a completion the user chose.
_Avoid_: map item, location

**Resolve**:
To turn a chosen completion into its placemark.
_Avoid_: geocode, look up, fetch details
