type {{ $.InterfaceName }}Response interface {
     Success(c *gin.Context, data interface{})
     Failed(c *gin.Context, err error)
}

type {{ $.InterfaceName }}Bind interface {
     Bind(c *gin.Context, params interface{}) error
}

type {{ $.InterfaceName }} interface {
{{range .MethodSet}}
	{{.Name}}(context.Context, *{{.Request}}) (*{{.Reply}}, error)
{{end}}
}

type {{$.Name}} struct{
	server {{ $.InterfaceName }}
	router gin.IRouter
	bind {{ $.InterfaceName }}Bind
	resp {{ $.InterfaceName }}Response
}

type {{$.Name}}Option func(*{{$.Name}})

type default{{ $.InterfaceName }}Bind struct{}

type default{{ $.InterfaceName }}Response struct{}

func (*default{{ $.InterfaceName }}Bind) Bind(c *gin.Context, params interface{}) error {
	b := binding.Default(c.Request.Method, c.ContentType())
	if err := c.ShouldBindWith(params, b); err != nil {
		return err
	}

	if err := binding.Form.Bind(c.Request, params); err != nil {
		return err
	}

	if err := c.ShouldBindUri(params); err != nil {
		return err
	}

	if err := c.ShouldBindHeader(params); err != nil {
		return err
	}

	return nil
}

func (*default{{ $.InterfaceName }}Response) Success(c *gin.Context, data interface{}) {
    c.JSON(200, gin.H{
        "code": 0,
        "msg": "success",
        "data": data,
    })
}

func (*default{{ $.InterfaceName }}Response) Failed(c *gin.Context, err error) {
    if err == nil {
        c.AbortWithStatus(500)
        return
    }
    c.JSON(500, gin.H{
        "code": 500,
        "msg": err.Error(),
    })
}

func New{{$.Name}}(server {{ $.InterfaceName }}, opts ...{{$.Name}}Option) *{{$.Name}} {
    s := &{{$.Name}}{
        server: server,
        bind: &default{{ $.InterfaceName }}Bind{},
        resp: &default{{ $.InterfaceName }}Response{},
    }
    for _, opt := range opts {
        if opt != nil {
            opt(s)
        }
    }
    return s
}

func WithRouter(router gin.IRouter) {{$.Name}}Option {
    return func(s *{{$.Name}}) {
        s.router = router
    }
}

func WithBind(bind {{ $.InterfaceName }}Bind) {{$.Name}}Option {
    return func(s *{{$.Name}}) {
        s.bind = bind
    }
}

func WithResponse(resp {{ $.InterfaceName }}Response) {{$.Name}}Option {
    return func(s *{{$.Name}}) {
        s.resp = resp
    }
}

func Register{{ $.InterfaceName }}(server *{{$.Name}}) {
	server.RegisterService()
}

{{range .Methods}}
func (s *{{$.Name}}) {{ .HandlerName }} (ctx *gin.Context) {
	var in {{.Request}}
    if err := s.bind.Bind(ctx, &in); err != nil {
    	s.resp.Failed(ctx, err)
    	return
    }

	md := metadata.New(nil)
	for k, v := range ctx.Request.Header {
		md.Set(k, v...)
	}
	newCtx := metadata.NewIncomingContext(ctx, md)
	out, err := s.server.({{ $.InterfaceName }}).{{.Name}}(newCtx, &in)
	if err != nil {
		s.resp.Failed(ctx, err)
		return
	}

	s.resp.Success(ctx, out)
}
{{end}}

func (s *{{$.Name}}) RegisterService() {
{{range .Methods}}
		s.router.Handle("{{.Method}}", "{{.Path}}", s.{{ .HandlerName }})
{{end}}
}