### what
Zigbo is a custom build step for the Zig build system. You can use this step to render a diagram of the Zig build graph.

### how
The Zig build system only asks you to not modify the build graph during "maketime" (build step execution). We are allowed to **READ** it then. Knowing this, we can traverse the build graph (in the same way that calling `make` would) and output a diagram (for now, only [mermaid](https://mermaid.js.org/#/)) allowing you to analyse, inspect, and digest your entire build graph.

### who
Zigbo was originally written by [haze](https://github.com/haze) and donated to [InKryption](https://github.com/InKryption) for maintenance.

### when
Zigbo was initially built between January 21st and January 24th.

### where
Zigbo was proudly built in New York City.

### example build graph (zigbo's)

``` mermaid
flowchart TD
	subgraph tls_0 [Copy build artifacts to prefix path]
	step_0[Opaque Top Level Step]
	step_0 --> step_1["InstallArtifactStep: (install zigbo)\ndestination: build.InstallDir{ .lib = void }"]
	step_1 --> step_2["LibExeObjStep (zigbo)\nkind: lib\nmode: Debug\nlinkage: static\nroot_src: '/Users/haze/Code/zigbo/src/main.zig'"]
	end
	subgraph tls_1 [Remove build artifacts from prefix path]
	step_3[Opaque Top Level Step]
	end
	subgraph tls_2 [Run library tests]
	step_4[Opaque Top Level Step]
	step_4 --> step_5["LibExeObjStep (test)\nkind: test\nmode: Debug\nroot_src: '/Users/haze/Code/zigbo/src/main.zig'"]
	end
	subgraph tls_3 [Output the build graph as a mermaid diagram]
	step_6[Opaque Top Level Step]
	step_6 --> step_7["Opaque Custom Step (Graph Output)"]
	end
```

<sup>
Licensed under either of <a href="LICENSE-APACHE">Apache License, Version
2.0</a> or <a href="LICENSE-MIT">MIT license</a> at your option.
</sup>

<br/>

<sub>
Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in this package by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.
</sub>
