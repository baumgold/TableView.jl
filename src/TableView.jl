module TableView

using WebIO
using JuliaDB

import JuliaDB: DNDSparse

function showtable(t::Union{DNDSparse, NDSparse}; rows=1:100, colopts=Dict(), kwargs...)
    w = Widget(dependencies=["https://cdnjs.cloudflare.com/ajax/libs/handsontable/0.34.0/handsontable.full.js",
                             "https://cdnjs.cloudflare.com/ajax/libs/handsontable/0.34.0/handsontable.full.css"])
    data = Observable{Any}(w, "data", [])

    ks = keys(t)[rows]
    vs = values(t)[rows]

    if !isa(keys(t), Columns)
         ks = collect(ks)
         vs = collect(vs)
    end

    subt = NDSparse(ks, vs)

    headers = colnames(subt)
    cols = [merge(Dict(:data=>n), get(colopts, n, Dict())) for n in headers]

    options = Dict(
        :data => JuliaDB.rows(subt),
        :colHeaders => headers,
        :fixedColumnsLeft => ndims(t),
        :modifyColWidth => @js(w -> w > 300 ? 300 : w),
        :modifyRowHeight => @js(h -> h > 60 ? 50 : h),
        :manualColumnResize => true,
        :manualRowResize => true,
        :columns => cols,
        :width => 800,
        :height => 400,
    )

    merge!(options, Dict(kwargs))

    handler = @js function (Handsontable)
        @var sizefix = document.createElement("style");
        sizefix.textContent = """
            .htCore td {
                white-space:nowrap
            }
        """
        this.dom.appendChild(sizefix)
        this.hot = @new Handsontable(this.dom, $options);
    end
    ondependencies(w, handler)
    w()
end

end # module
