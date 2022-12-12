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

func Register{{ $.InterfaceName }}(r gin.IRouter, srv {{ $.InterfaceName }}, resp {{ $.InterfaceName }}Response, bind {{ $.InterfaceName }}Bind) {
	s := {{.Name}}{
		server: srv,
		router: r,
		resp:   resp,
		bind:   bind,
	}
	s.RegisterService()
}

type {{$.Name}} struct{
	server {{ $.InterfaceName }}
	router gin.IRouter
	bind {{ $.InterfaceName }}Bind
	resp {{ $.InterfaceName }}Response
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