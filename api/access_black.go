package api

import (
	"fmt"
	"slices"
	"strings"
)

func prepareAccessBlackVars(req *QueryRequest, cubeName string) error {
	if cubeName != "AccessView" || !slices.Contains(req.Segments, "AccessView.black") {
		return nil
	}

	exact := req.Vars["api_filter_exact"]
	if len(exact) == 0 {
		exact = req.Vars["api_exact"]
	}
	regex := req.Vars["api_filter_regex"]
	if len(regex) == 0 {
		regex = req.Vars["api_regex"]
	}
	if len(exact) == 0 && len(regex) == 0 {
		return nil
	}

	var exactHosts, exactURLs, regexHosts, regexSuffixes []any
	for _, value := range exact {
		api, _ := value.(string)
		if api == "" {
			continue
		}
		host, path, ok := strings.Cut(api, "/")
		if !ok || host == "" {
			return fmt.Errorf("invalid api_filter_exact %q: expected host/url", api)
		}
		exactHosts = append(exactHosts, host)
		exactURLs = append(exactURLs, "/"+path)
	}

	for _, value := range regex {
		rule, _ := value.(string)
		rule = strings.TrimSpace(rule)
		if rule == "" {
			continue
		}
		host, matched, err := hostFilterRule(rule)
		if err != nil {
			return err
		}
		if matched {
			regexHosts = append(regexHosts, host)
			continue
		}
		for _, part := range strings.Split(rule, "|") {
			suffix, err := suffixFilterRule(part)
			if err != nil {
				return fmt.Errorf("unsupported api_filter_regex %q: %w", rule, err)
			}
			regexSuffixes = append(regexSuffixes, suffix)
		}
	}

	if req.Vars == nil {
		req.Vars = make(map[string][]any)
	}
	req.Vars["api_filter_exact_hosts"] = valuesOrEmpty(exactHosts)
	req.Vars["api_filter_exact_urls"] = valuesOrEmpty(exactURLs)
	req.Vars["api_filter_regex_hosts"] = valuesOrEmpty(regexHosts)
	req.Vars["api_filter_regex_suffixes"] = valuesOrEmpty(regexSuffixes)
	return nil
}

func hostFilterRule(rule string) (string, bool, error) {
	for _, suffix := range []string{"/.*", "/*"} {
		if host, ok := strings.CutSuffix(rule, suffix); ok {
			return parseHostRule(host)
		}
	}
	if host, ok := strings.CutSuffix(rule, "*"); ok {
		return parseHostRule(host)
	}
	return "", false, nil
}

func parseHostRule(expr string) (string, bool, error) {
	host, ok := regexLiteral(expr)
	if !ok || host == "." || strings.Contains(host, "/") {
		return "", true, fmt.Errorf("unsupported host rule %q", expr)
	}
	return host, true, nil
}

func suffixFilterRule(rule string) (string, error) {
	rule = strings.TrimSpace(rule)
	if !strings.HasSuffix(rule, "$") {
		return "", fmt.Errorf("expected host/* or literal url suffix$")
	}
	expr := strings.TrimSuffix(rule, "$")
	if strings.HasPrefix(expr, "^") {
		expr = strings.TrimPrefix(expr, "^")
		if !strings.HasPrefix(expr, ".*") {
			return "", fmt.Errorf("start anchor must be followed by .*")
		}
	}
	expr = strings.TrimPrefix(expr, ".*")
	suffix, ok := regexLiteral(expr)
	if !ok {
		return "", fmt.Errorf("suffix is not a literal")
	}
	return suffix, nil
}

func regexLiteral(expr string) (string, bool) {
	if expr == "" {
		return "", false
	}
	var literal strings.Builder
	for i := 0; i < len(expr); i++ {
		char := expr[i]
		if char == '\\' {
			i++
			if i == len(expr) || !strings.ContainsRune(`\\.+*?()|[]{}^$`, rune(expr[i])) {
				return "", false
			}
			literal.WriteByte(expr[i])
			continue
		}
		if strings.ContainsRune(`^$*+?()|[]{}`, rune(char)) {
			return "", false
		}
		literal.WriteByte(char)
	}
	return literal.String(), literal.Len() > 0
}

func valuesOrEmpty(values []any) []any {
	if len(values) == 0 {
		return []any{""}
	}
	return values
}
