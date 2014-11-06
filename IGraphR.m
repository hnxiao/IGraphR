(* ::Package:: *)

(* :Title:   IGraphR          *)
(* :Context: IGraphR`         *)
(* :Author:  Szabolcs Horvát  *)

(* :Package Version:     0.2  *)
(* :Mathematica Version: 9.0  *)

BeginPackage["IGraphR`", {"RLink`"}]

IGraph::usage = "IGraph[\"fun\"] is a callable object representing an igraph function.  Graph objects in arguments are automatically converted."

Begin["`Private`"]


Check[
  InstallR[];
  REvaluate["library(igraph)"]
  ,
  Message[IGraph::igraph];
  Abort[]
]


IGraph::igraph = "igraph is not available.  Make sure you are using an R installation that has the igraph package installed."
IGraph::mixed = "Mixed graphs are not supported."


RDataTypeRegister["IGraphEdgeList",
  g_?GraphQ,
  g_?GraphQ :>
    If[TrueQ@MixedGraphQ[g] (* TrueQ is to keep this v9-compatible; note v9 doesn't have MixedGraphQ defined *)
      ,
      Message[IGraph::mixed]; $Failed
      ,
      With[{d=DirectedGraphQ[g], vc=VertexCount[g], names=ToString /@ VertexList[g]},
        RObject[
          Replace[ List@@Join@@EdgeList[g], Dispatch@Thread[VertexList[g] -> Range[vc]], {1} ],
          RAttributes["mmaDirectedGraph" :> {d}, "mmaVertexCount" :> {vc}, "mmaVertexNames" :> names]
        ]
      ]
    ],
  o_RObject /; (RLink`RDataTypeTools`RExtractAttribute[o, "mmaDirectedGraph"] =!= $Failed),
  o:RObject[data_, _RAttributes] /; (RLink`RDataTypeTools`RExtractAttribute[o, "mmaDirectedGraph"] =!= $Failed) :>
    With[
      {vertices = Range@First@RLink`RDataTypeTools`RExtractAttribute[o, "mmaVertexCount"],
       edges = Partition[data, 2]}
      ,
      If[First@RLink`RDataTypeTools`RExtractAttribute[o, "mmaDirectedGraph"],
        Graph[vertices, DirectedEdge @@@ edges],
        Graph[vertices, UndirectedEdge @@@ edges]
      ]
    ]
]

iIGraph = 
  RFunction["function (fun, args) {
    res <- do.call(fun,
            lapply(
              args,
              function (x)
                if (is.null(attr(x, 'mmaDirectedGraph', exact=T))) x
                else {
                  g <- graph(x, n=attr(x, 'mmaVertexCount'), directed=attr(x, 'mmaDirectedGraph'))
                  V(g)$name <- attr(x, 'mmaVertexNames')
                  g
                }
            )
    )
    if (is.igraph(res)) {
      el <- as.integer(t(get.edgelist(res, names=F)))
      attr(el, 'mmaDirectedGraph') <- is.directed(res)
      attr(el, 'mmaVertexCount') <- vcount(res)
      attr(el, 'mmaVertexNames') <- get.vertex.attribute(res, 'name')
      el
    }
    else res
  }"];

IGraph[fun_String][args___] :=
    Module[{rargs},
      rargs = Check[ToRForm /@ {args}, $Failed];
      If[rargs =!= $Failed,
        iIGraph[RFunction[fun],
            ToRForm[rargs]
        ],
        $Failed
      ]
    ]


End[] (* `Private` *)

EndPackage[] (* IGraphR` *)
