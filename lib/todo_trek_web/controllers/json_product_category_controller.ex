defmodule TodoTrekWeb.JsonProductCategoryController do
  use TodoTrekWeb, :controller

  alias NimbleCSV.RFC4180, as: CSV
  alias TodoTrekWeb.MissingParameter

  defp retrieve_product_category_list() do
    # you might consider to cache the output of this function
    "priv/data/product/productcat.csv" 
    |> File.stream!
    |> CSV.parse_stream 
    |> Stream.map(fn [name, code, descr] ->
         %{name: name, code: code, description: descr}
       end)             
  end

  defp safe_downcase(text) do
    if is_nil(text), do: nil, else: String.downcase(text)
  end

  defp filter_product_category(params) do
    id = safe_downcase(params["name"])
    starts_with = safe_downcase(params["starts-with"])
    contains = safe_downcase(params["contains"])
    if is_nil(id) and is_nil(starts_with) and is_nil(contains), do: raise(MissingParameter, message: "Missing parameter name,starts-with or contains.")
    search_fields_str = safe_downcase(params["search-fields"]) || "name"
    search_fields = String.split(search_fields_str, ",")
    search_name  = Enum.member?(search_fields, "name")
    search_descr = Enum.member?(search_fields, "description")
    search_code  = Enum.member?(search_fields, "code")
    product_category_list = retrieve_product_category_list()
    filter = 
       fn(rec) -> (    is_nil(id)
                   or  String.downcase(rec.name) == id
                  ) 
                  and
                  (    is_nil(starts_with) 
                   or (search_name  and String.starts_with?(String.downcase(rec.name), starts_with)) 
                   or (search_code  and String.starts_with?(String.downcase(rec.code), starts_with))
                   or (search_descr and String.starts_with?(String.downcase(rec.description), starts_with))
                  ) 
                  and
                  (    is_nil(contains)
                   or (search_name  and String.contains?(String.downcase(rec.name), contains))
                   or (search_code  and String.contains?(String.downcase(rec.code), contains))
                   or (search_descr and String.contains?(String.downcase(rec.description), contains))
                  )
       end
    Enum.filter(product_category_list, filter)
  end

  def index(conn, params) do
    product_category_list =
       if Enum.empty?(params) do
         retrieve_product_category_list() 
         |> Enum.to_list
       else
         filter_product_category(params)
       end
    # json(conn, %{productcat: product_category_list})             # render without view TodoTrekWeb.JsonProductCategoryJSON.ex
    render(conn, "index.json", productcat: product_category_list)  # render using a view
  end
end
