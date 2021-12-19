# find_private_types
 Finds types not exported in Erlang modules but referenced by exported functions. [Issue #5530](https://github.com/erlang/otp/issues/5530)

# Run

Clone repository and run the following on the command line:

```
elixir find_private_types.exs
```

# Details

Goes through every Erlang kernel module and gets the docs using `Code.fetch_docs/1`. Some modules don't have docs and these are ignored.

The docs are parsed to extract all exported types and then every
function is parsed to extract any "user types" that the function
refers to. Any user types which are not exported are displayed
in the output along with the module name. If a module does not
have any referenced types which were not exported, then it is not
printed at all.

# Output

As at when this code was committed (OTP/24) the current list of
types referenced but not exported is available in the file:
`private_types.txt`.