defmodule TodoTrekWeb.Router do
  use TodoTrekWeb, :router

  import TodoTrekWeb.UserAuth

  @host :todo_trek
        |> Application.compile_env!(TodoTrekWeb.Endpoint)
        |> Keyword.fetch!(:url)
        |> Keyword.fetch!(:host)

  @content_security_policy "default-src 'self';" <>
     "connect-src ws://#{@host}:* https://api.github.com/search/users https://raw.githubusercontent.com/nico-amsterdam/;" <>
     "style-src  'self' 'unsafe-inline';" <> 
     "script-src 'self';" <>
     "img-src    'self' blob: data:;" <>
     "font-src                data:;"

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {TodoTrekWeb.Layouts, :root}
    plug :protect_from_forgery
    plug(:put_secure_browser_headers, %{"content-security-policy" => @content_security_policy})
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  defp max_age(conn, max_age) when is_integer(max_age) do
    Plug.Conn.put_resp_header(conn, "cache-control", "max-age=" <> to_string(max_age))
  end

  pipeline :api_cached do
    plug :accepts, ["json"]
    plug :max_age, 60 * 60 * 12
    # plug :origin, "*"
  end

  scope "/", TodoTrekWeb do
    pipe_through :browser

    live_session :default,
      on_mount: [{TodoTrekWeb.UserAuth, :ensure_authenticated}, TodoTrekWeb.Scope] do
      live "/", HomeLive, :dashboard
      live "/lists/new", HomeLive, :new_list
      live "/lists/:id/edit", HomeLive, :edit_list
    end
  end

  #
  # JSON API's
  #
  scope "/rest/public", TodoTrekWeb do
    pipe_through :api_cached

    # get "/v1/productcat", JsonProductCategoryController, :index
    resources "/v1/productcat", JsonProductCategoryController, only: [:index]
    # options   "/v1/productcat", JsonProductCategoryController, :options
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
