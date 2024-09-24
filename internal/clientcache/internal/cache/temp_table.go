package cache

import (
	"context"
	"fmt"
	"strings"

	"github.com/hashicorp/boundary/internal/db"
	"github.com/hashicorp/boundary/internal/errors"
	"github.com/hashicorp/boundary/internal/util"
)

type resourceTabler interface {
	TableName() string
}

const (
	sqlFindCreateTableStmt = "select sql from sqlite_master where type='table' AND name=?"
	tmpTblSuffix           = "_refresh_tmp"
	targetTblName          = "target"
	sessionTblName         = "session"
	resolvableAliasTblName = "resolvable_alias"
)

func createTmpTableForResource(ctx context.Context, w db.Writer, resource resourceTabler) error {
	const op = "cache.createTmpTableForResource"
	switch {
	case w == nil:
		return errors.New(ctx, errors.InvalidParameter, op, "missing db")
	case util.IsNil(resource):
		return errors.New(ctx, errors.InvalidParameter, op, "missing resource tabler")
	}

	tmpTblName, err := tempTableName(ctx, resource)
	if err != nil {
		return errors.Wrap(ctx, err, op)
	}
	baseTableName := strings.ToLower(resource.TableName())

	rows, err := w.Query(ctx, "", nil)
	if err != nil {
		return errors.Wrap(ctx, err, op)
	}
	var createTableSql string
	for rows.Next() {
		if err := w.ScanRows(ctx, rows, &createTableSql); err != nil {
			return errors.Wrap(ctx, err, op)
		}
	}
	if err := rows.Err(); err != nil {
		return errors.Wrap(ctx, err, op)
	}
	createTableSql = strings.Replace(strings.ToLower(createTableSql), baseTableName, tmpTblName, 1)
	if _, err := w.Exec(ctx, createTableSql, nil); err != nil {
		return errors.Wrap(ctx, err, op)
	}

	return nil
}

func tempTableName(ctx context.Context, resource resourceTabler) (string, error) {
	const op = "cache.tempTableName"
	switch {
	case util.IsNil(resource):
		return "", errors.New(ctx, errors.InvalidParameter, op, "missing resource tabler")
	}
	baseTableName := strings.ToLower(resource.TableName())
	switch baseTableName {
	case targetTblName, sessionTblName, resolvableAliasTblName:
	default:
		return "", errors.New(ctx, errors.InvalidParameter, op, fmt.Sprintf("unable to create a temp table for %s, it is not a supported base table for creating a temp table", baseTableName))
	}
	return baseTableName + tmpTblSuffix, nil
}
