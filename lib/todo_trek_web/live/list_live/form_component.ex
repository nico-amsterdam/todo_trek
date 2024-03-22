defmodule TodoTrekWeb.ListLive.FormComponent do
  use TodoTrekWeb, :live_component

  alias TodoTrek.Todos

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header><%= @title %></.header>
      <.simple_form
        for={@form}
        id="list-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4 mb-6">
          <.input field={@form[:title]} type="text" />
          <.release_dom id={"#{@form[:country].id}-domspace"} >

            <.input field={@form[:country]} type="text" placeholder="Country autocomplete test" />

            <.input field={@form[:capital]} type="text" placeholder="Capital autocomplete test" />

            <div id="awe-capital"></div>


             <.copy_value_to_id
                 field={@form[:country]}
                 dataField="capital"
                 target="#awe-capital"
                 />

             <.copy_value_to_id
                 field={@form[:capital]}
                 dataField="capital"
                 target="#awe-capital"
                 />

             <.copy_value_to_field
                 sourceField={@form[:country]}
                 dataField="capital"
                 targetField={@form[:capital]}
                 />

             <.copy_value_to_field
                 sourceField={@form[:capital]}
                 dataField="name"
                 targetField={@form[:country]}
                 />

            <.autocomplete    forField={@form[:country]}
                              url="https://restcountries.com/v2/all"
                              loadall="true"
                              prepop="true"
                              minChars="1" 
                              maxItems="8" 
                              value="name"     
                              descr="capital"
                              descrSearch="true"
                              />

            <.autocomplete    forField={@form[:capital]}
                              url="https://restcountries.com/v2/all"
                              loadall="true"
                              prepop="true"
                              minChars="1" 
                              maxItems="8" 
                              value="capital"
                              />

            <.input field={@form[:color]} type="text" placeholder="Color autocomplete test" />

            <.autocomplete 
              forField={@form[:color]}
              minChars="1"
              filter="filterContains"
              list="listWithLabels"   
            />

            <.input field={@form[:alphabet]} type="text" placeholder="Make a sentence with all letters of the alphabet" />

            <.autocomplete
              forField={@form[:alphabet]}
              minChars="1"
              multiple=" ,"
              list="The,quick,brown,fox,jumps,over,the,lazy,dog,Pack,my,box,with,five,dozen,liquor,jugs"   
            />


            <.input field={@form[:textwithreferences]} type="textarea" placeholder="Write a text and use @ to reference people" />

            <datalist id="peoplelist">
              <option>Ada</option>
              <option>Beyonce</option>
              <option>Chris</option>
              <option>Danny</option>
              <option>Edward</option>
              <option>Frank</option>
              <option>Gerard</option>
              <option>Hanna</option>
              <option>Iris</option>
              <option>John</option>
              <option>Kate</option>
              <option>Leo</option>
              <option>Max</option>
              <option>Neo</option>
              <option>Olivia</option>
              <option>Penny</option>
              <option>Quincey</option>
              <option>Ryan</option>
              <option>Sarah</option>
              <option>Tara</option>
              <option>Umar</option>
              <option>Veronica</option>
              <option>Wendy</option>
              <option>Xena</option>
              <option>Yasmine</option>
              <option>Zara</option>
            </datalist>
            <.autocomplete
              forField={@form[:textwithreferences]}
              minChars="1"
              multiple="@"
              replace="replaceAtSign"
              filter="filterAtSign"
              convertInput="convertInputAtSign"
              list="#peoplelist"   
            />

          </.release_dom>
          <label class="block cursor-pointer">
            <input type="checkbox" name="list[notifications_order][]" class="hidden" />
            <.icon name="hero-plus-circle" /> prepend
          </label>
          <h1 class="text-md font-semibold leading-8 text-zinc-800">
            Invite Users
          </h1>
          <div id="notifications" phx-hook="SortableInputsFor" class="space-y-2">
            <.inputs_for :let={f_nested} field={@form[:notifications]}>
              <div class="flex space-x-2 drag-item">
                <input type="hidden" name="list[notifications_order][]" value={f_nested.index} />
                <.icon name="hero-bars-3" class="w-6 h-6 relative top-2" data-handle />
                <.input type="text" field={f_nested[:email]} placeholder="email" />
                <.input type="text" field={f_nested[:name]} placeholder="name" />
                <label>
                  <input
                    type="checkbox"
                    name="list[
                      \
                    ][]"
                    value={f_nested.index}
                    class="hidden"
                  />
                  <.icon name="hero-x-mark" class="w-6 h-6 relative top-2" />
                </label>
              </div>
            </.inputs_for>
          </div>

          <label class="block cursor-pointer">
            <input type="checkbox" name="list[notifications_order][]" class="hidden" />
            <.icon name="hero-plus-circle" /> add more
          </label>
        </div>

        <input type="hidden" name="list[notifications_delete][]" />

        <:actions>
          <.button phx-disable-with="Saving...">
            Save List
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{list: list} = assigns, socket) do
    changeset = Todos.change_list(list)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"list" => list_params}, socket) do
    changeset =
      socket.assigns.list
      |> Todos.change_list(list_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"list" => list_params}, socket) do
    save_list(socket, socket.assigns.action, list_params)
  end

  defp save_list(socket, :edit_list, list_params) do
    case Todos.update_list(socket.assigns.scope, socket.assigns.list, list_params) do
      {:ok, _list} ->
        {:noreply,
         socket
         |> put_flash(:info, "List updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_list(socket, :new_list, list_params) do
    case Todos.create_list(socket.assigns.scope, list_params) do
      {:ok, _list} ->
        {:noreply,
         socket
         |> put_flash(:info, "List created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
