root = exports ? this

class Cummar
  constructor: ->
    @button = $("@save-button")
    @local_contacts = $('@contacts[data-contacts-type="local"] @contact')

    @local_contacts.find("@update-container").add('@contacts[data-contacts-type="remote"]').droppable({
      accepts: ".contact",
      drop: (ev, ui) =>
        ui.draggable.prependTo($(ev.target))
        @button.toggleClass("disabled", @local_contacts.filter(':has("@update-container @contact")').size() == 0)
    })

    $('@contacts[data-contacts-type="remote"] @contact').draggable({cursor: "move", appendTo: "body", helper: "clone"})

    $("button").on("click", @save)
    $("@contacts-search").on("keyup", @search)

  save: =>
    return if @button.hasClass("disabled")
    @button.addClass("disabled")

    to_update = @local_contacts.filter(':has("@update-container @contact")').toArray().map((el) -> $(el))

    updates = to_update.reduce(((accumulator, element) ->
      data = element.find("@contact").data()

      accumulator[element.data("id")] = Cummar.supported_fields.reduce(((update, field) ->
        update[field] = data[field] if data[field]? && element.find("""input[type="checkbox"][data-contact-switch="#{field}"]""").is(":checked")
        update
      ), {})

      accumulator
    ), {})

    $("form input").val(JSON.stringify(updates))
    $("form").submit()

  search: (ev) =>
    field = $(ev.target)
    query = field.val().toLowerCase()
    targets = $("""@contacts[data-contacts-type="#{field.attr("data-contacts-type")}"] @contact""")

    if query.isBlank()
      targets.removeClass("hide")
    else
      targets.each((index, el) ->
        match = $(el).attr("data-tag")
        $(el).toggleClass("hide", match.indexOf(query) != 0)
      )


root.Cummar = Cummar
jQuery.expr.match.ROLE = /^@((?:\\.|[\w-]|[^\x00-\xa0])+)/
jQuery.expr.filter.ROLE = (role) ->
  (element) -> element.getAttribute("data-role") == role

jQuery(window).on("ready", ->
  cummar = new Cummar()
)