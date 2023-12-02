defmodule TodoTrekWeb.JsonProductCategoryJSON do

  @doc """
  Renders a list of product categories.
  """
  def render("index.json", %{productcat: productcat}) do
    %{productcat: productcat}
  end

end
