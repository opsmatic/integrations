### Installation

* Place `opsmatic_callback_v1.py` into the directory that is specified as
`callback_plugins` in your `ansible.cfg`. If this is your first callback, this
would be an opportune time to make a decision about where you want those to
live (probably somewhere in your ansible repo?) Add a section to your
* `ansible.cfg` which looks like this:

```ini
[opsmatic]
integration_token = <your integration token>
```
