defmodule TodoTrekWeb.Router do
  use TodoTrekWeb, :router

  import TodoTrekWeb.UserAuth

  # @generated_nonce "xyz" 
  @generated_nonce 10 
                   |> :crypto.strong_rand_bytes 
                   |> Base.url_encode64(padding: false)

  # TODO: use a new generated nonce at every page reload (like with the _csrf_token)
  def assign_script_nonce(%Plug.Conn{} = conn, _) do
     conn
     |> assign(:script_src_nonce, @generated_nonce)
  end

  @host :todo_trek
        |> Application.compile_env!(TodoTrekWeb.Endpoint)
        |> Keyword.fetch!(:url)
        |> Keyword.fetch!(:host)

  @content_security_policy "default-src 'self' 'unsafe-eval' 'unsafe-inline';" <>
     "connect-src ws://#{@host}:* https://restcountries.com/v2/all;" <>
     "style-src 'self' 'unsafe-inline' http://nico-amsterdam.github.io/awesomplete-util/css/awesomplete.css;" <>
     # "script-src 'self' 'unsafe-inline' http://nico-amsterdam.github.io/awesomplete-util/js/awesomplete-v2020.min.js" <>
     "script-src 'self' 'nonce-" <> @generated_nonce <> "' http://nico-amsterdam.github.io/awesomplete-util/js/awesomplete-v2020.min.js" <>
                                      " http://nico-amsterdam.github.io/awesomplete-util/js/awesomplete-util.min.js;" <>
     "img-src 'self' blob: data:;" <>
     "font-src data:;"


  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {TodoTrekWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :fetch_current_user
    plug(:put_secure_browser_headers, %{"content-security-policy" => @content_security_policy})
    plug :assign_script_nonce
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TodoTrekWeb do
    pipe_through :browser

    live_session :default,
      # socket.assigns needs the nonce to put it on the script tag in the HTML output.
      on_mount: [{TodoTrekWeb.UserAuth, :ensure_authenticated}, TodoTrekWeb.Scope, {TodoTrekWeb.Nonce, %{script_src_nonce: @generated_nonce}}] do
      live "/", HomeLive, :dashboard
      live "/lists/new", HomeLive, :new_list
      live "/lists/:id/edit", HomeLive, :edit_list
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", TodoTrekWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:todo_trek, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TodoTrekWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TodoTrekWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{TodoTrekWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", TodoTrekWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{TodoTrekWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", TodoTrekWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{TodoTrekWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

end
