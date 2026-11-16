
## Sources of Non Determinism in Roc Apps

| Source                 | basic-cli module                         | In the simulator                                           |
| ---------------------- | ---------------------------------------- | ---------------------------------------------------------- |
| Network                | `Tcp`                                    | Seeded message bus                                         |
| Disk                   | `File`, `Path`, `Sqlite`                 | idk                                                        |
| Time                   | `Sleep`, `Utc`, `Duration`, `Monotonic`               | virtual time                                      |
| Randomness             | `Random`                                 | Seeded random number generator                             |
| Floating Point Numbers | Roc guarantees determistic FP operations | Floats only reach the platfrom through the `Sqlite` module |
| Memory                 |                                          |                                                            |
| Language constructs    | deterministic                            | Has do avoid e.g. HashMap iterations                       |
| Concurrency            | Not available only blocking I/O          | -                                                          |
