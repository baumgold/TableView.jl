module TableView
using Tables, TableTraits, IteratorInterfaceExtensions
using WebIO, JSExpr, JSON, Dates
using Observables: @map

function showtable(x; dark = false)
    if Tables.istable(typeof(x))
        return _showtable(x, dark)
    elseif TableTraits.isiterabletable(x)
        it = IteratorInterfaceExtensions.getiterator(x)
        return _showtable(Tables.DataValueUnwrapper(it), dark)
    end
    throw(ArgumentError("Argument is not a table."))
end

function _showtable(table, dark)
    length(Tables.rows(table)) > 10_000 ? _showtable_async(table, dark) :
                                          _showtable_sync(table, dark)
end

function _showtable_sync(table, dark)
    schema = Tables.schema(table)
    names = schema.names
    types = schema.types
    rows = Tables.rows(table)

    w = Scope(imports=["https://unpkg.com/ag-grid-community/dist/ag-grid-community.min.noStyle.js",
                       "https://unpkg.com/ag-grid-community/dist/styles/ag-grid.css",
                       "https://unpkg.com/ag-grid-community/dist/styles/ag-theme-balham$(dark ? "-dark" : "").css",])

    coldefs = [(
                    headerName = n,
                    headerTooltip = types[i],
                    field = n,
                    type = types[i] <: Union{Missing, T where T <: Number} ? "numericColumn" : nothing,
                    filter = types[i] <: Union{Missing, T where T <: Dates.Date} ? "agDateColumnFilter" :
                             types[i] <: Union{Missing, T where T <: Number} ? "agNumberColumnFilter" : nothing
               ) for (i, n) in enumerate(names)]

    options = Dict(
        :rowData => table2json(rows, names, types),
        :columnDefs => coldefs,
        :enableSorting => true,
        :enableFilter => true,
        :enableColResize => true,
        :multiSortKey => "ctrl",
    )

    handler = @js function (agGrid)
        gridOptions = $options
        gridOptions.rowData = JSON.parse(gridOptions.rowData)
        this.table = @new agGrid.Grid(this.dom.querySelector("#grid"), gridOptions)
        gridOptions.columnApi.autoSizeColumns($names)
    end
    onimport(w, handler)
    w.dom = dom"div#grid"(className = "ag-theme-balham$(dark ? "-dark" : "")",
                          style=Dict(:width => "100%",
                                     "min-width" => "400px",
                                     :height => "800px"))
    w
end


function _showtable_async(table, dark)
    schema = Tables.schema(table)
    names = schema.names
    types = schema.types
    rows = Tables.rows(table)

    w = Scope(imports=["https://unpkg.com/ag-grid-community/dist/ag-grid-community.min.noStyle.js",
                       "https://unpkg.com/ag-grid-community/dist/styles/ag-grid.css",
                       "https://unpkg.com/ag-grid-community/dist/styles/ag-theme-balham$(dark ? "-dark" : "").css",])

    coldefs = [(
                    headerName = n,
                    headerTooltip = types[i],
                    field = n,
                    type = types[i] <: Union{Missing, T where T <: Number} ? "numericColumn" : nothing,
                    filter = types[i] <: Union{Missing, T where T <: Dates.Date} ? "agDateColumnFilter" :
                             types[i] <: Union{Missing, T where T <: Number} ? "agNumberColumnFilter" : nothing
               ) for (i, n) in enumerate(names)]

    rowparams = Observable(w, "rowparams", Dict("startRow" => 1,
                                                "endRow" => 100,
                                                "successCallback" => @js v -> nothing))
    requestedrows = Observable(w, "requestedrows", "")
    on(rowparams) do x
        requestedrows[] = table2json(rows, names, types, requested = [x["startRow"], x["endRow"]])
    end

    onjs(requestedrows, @js function (val)
        ($rowparams[]).successCallback(JSON.parse(val), $(length(rows)))
    end)

    options = Dict(
        :columnDefs => coldefs,
        :enableSorting => true,
        :enableFilter => true,
        :maxConcurrentDatasourceRequests => 1,
        :cacheBlockSize => 1000,
        :maxBlocksInCache => 100,
        :enableColResize => true,
        :multiSortKey => "ctrl",
        :rowModelType => "infinite",
        :datasource => Dict(
            "getRows" =>
                @js function (rowParams)
                    $rowparams[] = rowParams
                end
            ,
            "rowCount" => length(rows)
        )
    )

    handler = @js function (agGrid)
        gridOptions = $options
        # gridOptions.rowData = JSON.parse(gridOptions.rowData)
        this.table = @new agGrid.Grid(this.dom.querySelector("#grid"), gridOptions)
        gridOptions.columnApi.autoSizeColumns($names)
    end
    onimport(w, handler)
    w.dom = dom"div#grid"(className = "ag-theme-balham$(dark ? "-dark" : "")",
                          style=Dict(:width => "100%",
                                     "min-width" => "400px",
                                     :height => "800px"))
    w
end

# directly write JSON instead of allocating temporary dicts etc
function table2json(rows, names, types; requested = nothing)
    io = IOBuffer()
    print(io, '[')
    for (i, row) in enumerate(rows)
        if requested == nothing || first(requested) <= i <= last(requested)
            print(io, '{')
            i = 1
            for col in Tables.eachcolumn(row)
                JSON.print(io, names[i])
                i += 1
                print(io, ':')
                if col isa Number
                    JSON.print(io, col)
                else
                    JSON.print(io, sprint(print, col))
                end
                print(io, ',')
            end
            skip(io, -1)
            print(io, '}')
            print(io, ',')
        end
    end
    skip(io, -1)
    print(io, ']')

    String(take!(io))
end
end
