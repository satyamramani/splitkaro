/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("expenses");

  collection.fields.addAt(5, new TextField({
    "name": "group",
    "required": false,
  }));

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("expenses");

  collection.fields.removeByName("group");

  return app.save(collection);
});
